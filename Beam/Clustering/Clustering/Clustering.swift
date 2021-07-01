import LASwift
import Foundation
import NaturalLanguage
import Accelerate

struct EntitiesInText {
    var entities = ["PersonalName": [String](), "PlaceName": [String](), "OrganizationName": [String]()]
}

public struct Page {
    public init(id: UInt64, parentId: UInt64? = nil, title: String? = nil, content: String? = nil) {
        self.id = id
        self.parentId = parentId
        self.title = title
        self.content = content
    }

    var id: UInt64
    var parentId: UInt64?
    var title: String?
    var content: String?
    var textEmbedding: [Double]?
    var entities: EntitiesInText?
    var language: NLLanguage?
    var entitiesInTitle: EntitiesInText?
}

enum ClusteringCandidate {
    case nonNormalizedLaplacian
    case randomWalkLaplacian
    case symetricLaplacian
    case similarityMatrix
}

enum SimilarityMatrixCandidate {
    case navigationMatrix
    case navigationAndEntities
    case textualSimilarityMatrix
    case combinationAllSimilarityMatrix
    case combinationAllBinarisedMatrix
    case combinationBinarizedWithTextErasure
}

enum NumClusterComputationCandidate {
    case threshold
    case biggestDistanceInPercentages
    case biggestDistanceInAbsolute
}

// swiftlint:disable:next type_body_length
public class Cluster {

    enum FindEntitiesIn {
        case content
        case title
    }

    enum MatrixError: Error {
        case dimensionsNotMatching
        case matrixNotSquare
        case pageOutOfDimensions
    }

    enum CandidateError: Error {
        case unknownCandidate
    }

    enum MatrixTypeError: Error {
        case unknownMatrixType
    }

    let myQueue = DispatchQueue(label: "clusteringThread")
    var pages = [Page]()
    // As the adjacency matrix is never touched on its own, just through the sub matrices, it
    // does not need add or remove methods.
    var adjacencyMatrix = Matrix([[0]])
    var navigationMatrix = NavigationMatrix()
    var textualSimilarityMatrix = SimilarityMatrix()
    var entitiesMatrix = SimilarityMatrix()
    let tagger = NLTagger(tagSchemes: [.nameType])
    let entityOptions: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
    let entityTags: [NLTag] = [.personalName, .placeName, .organizationName]
    var timeToRemove = 0.5
    let titleSuffixes = [" - Google Search", " - YouTube"]

    // The following will be deleted before the final product:
    // Define which affinity (laplacian) matrix to use
    var clusteringCandidate = ClusteringCandidate.nonNormalizedLaplacian
    // Define which similarity matrix to use
    var matrixCandidate = SimilarityMatrixCandidate.navigationMatrix
    // Define which number of clusters computation to use
    var numClustersCandidate = NumClusterComputationCandidate.threshold
    var candidate: Int
    var weights = [String: Double]()

    public init(candidate: Int = 1, weightNavigation: Double = 0.5, weightText: Double = 0.5, weightEntities: Double = 0.5) {
        self.candidate = candidate
        self.weights["navigation"] = weightNavigation
        self.weights["text"] = weightText
        self.weights["entities"] = weightEntities
        // In general we always initialise with candidate 1
        // this is just to be safe:
        do {
            try self.performCandidateChange()
        } catch {
            fatalError()
        }
    }

    public class SimilarityMatrix {
        var matrix = Matrix([[0]])

        func addPage(similarities: [Double]) throws {
            guard matrix.rows == matrix.cols else {
              throw MatrixError.matrixNotSquare
            }
            guard matrix.rows == similarities.count else {
              throw MatrixError.dimensionsNotMatching
            }
            self.matrix = self.matrix ||| similarities
            var similarities_row = similarities
            similarities_row.append(0.0)
            self.matrix = self.matrix === similarities_row
        }

        func removePage(index: Int) throws {
            guard matrix.rows == matrix.cols else {
              throw MatrixError.matrixNotSquare
            }
            guard index <= matrix.rows else {
              throw MatrixError.pageOutOfDimensions
            }
            switch index {
            case 0:
                self.matrix = self.matrix ?? (.Drop(1), .Drop(1))
            case self.matrix.rows - 1:
                self.matrix = self.matrix ?? (.DropLast(1), .DropLast(1))
            default:
                let upLeft = self.matrix ?? (.Take(index), .Take(index))
                let upRight = self.matrix ?? (.Take(index), .TakeLast(self.matrix.rows - index - 1))
                let downLeft = self.matrix ?? (.TakeLast(self.matrix.rows - index - 1), .Take(index))
                let downRight = self.matrix ?? (.TakeLast(self.matrix.rows - index - 1), .TakeLast(self.matrix.rows - index - 1))
                let left = upLeft === downLeft
                let right = upRight === downRight
                self.matrix = left ||| right
            }
        }
    }

   public class NavigationMatrix: SimilarityMatrix {
        override func removePage(index: Int) throws {
            var connectionsVct = (self.matrix ?? (.Pos([index]), .All)).flat
            connectionsVct.remove(at: index)
            try super.removePage(index: index)
            for i in 0..<self.matrix.rows where connectionsVct[i] == 1.0 {
                for j in 0..<self.matrix.rows where i != j && connectionsVct[j] == 1.0 {
                    self.matrix[i, j] = 1.0
                    self.matrix[j, i] = 1.0
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func clusterize() throws -> [Int] {
        guard self.adjacencyMatrix.rows >= 2 else {
            return zeros(1, self.adjacencyMatrix.rows).flat.map { Int($0) }
        }
        let d = reduce(self.adjacencyMatrix, sum, .Row)
        let d1: [Double] = d.map { elem in
            if elem == 0.0 { return 0.0 } else { return 1 / elem }
        }
        let D = diag(d)
        let D1 = diag(d1)
        // This naming makes sense as D1 is 1/D
        let laplacianNn = D - self.adjacencyMatrix
        // This is the 'simplest' non-normalized Laplacian

        var laplacian: Matrix
        switch self.clusteringCandidate { // This switch takes care of the choice of Laplacian
        case .nonNormalizedLaplacian: // Non-normalised graph Laplacian
            laplacian = laplacianNn
        case .randomWalkLaplacian: // Random-walk Laplacian
            laplacian = D1 * laplacianNn
        case .symetricLaplacian: // Symmetric Laplacian
            laplacian = sqrt(D1) * laplacianNn * sqrt(D1)
        case .similarityMatrix:
            laplacian = self.adjacencyMatrix
        }
        //TODO: If necessary, add the Laplacian of Zelnik-Manor

        let eigen = eig(laplacian)
        var eigenVals = reduce(eigen.D, sum)
        let indices = eigenVals.indices
        let combined = zip(eigenVals, indices).sorted { $0.0 < $1.0 }
        eigenVals = combined.map { $0.0 }
        let permutation = combined.map { $0.1 }
        var eigenVcts = eigen.V ?? (.All, .Pos(permutation))

        var numClusters: Int
        switch self.numClustersCandidate { // This switch takes care of the number of total classes
        case .threshold: // Threshold
            eigenVals.removeAll(where: { $0 > 1e-5 })
            numClusters = eigenVals.count
        case .biggestDistanceInPercentages: // Biggest distance in percentages
            let eigenValsDifference = zip(eigenVals, eigenVals.dropFirst()).map { abs(($1 - $0) / max($0, 0.0001)) }
            let maxDifference = eigenValsDifference.max() ?? 0
            numClusters = (eigenValsDifference.firstIndex(of: maxDifference) ?? 0) + 1
        case .biggestDistanceInAbsolute: // Biggest distance, absolute
            var eigenValsDifference = zip(eigenVals, eigenVals.dropFirst()).map { abs(($1 - $0)) }
            eigenValsDifference = eigenValsDifference.map { ($0 * 100).rounded() / 100 }
            let maxDifference = eigenValsDifference.max() ?? 0
            numClusters = (eigenValsDifference.firstIndex(of: maxDifference) ?? 0) + 1
        }

        guard numClusters > 1 else {
            return zeros(1, self.adjacencyMatrix.rows).flat.map { Int($0) }
        }
        if eigenVcts.cols > numClusters {
            eigenVcts = eigenVcts ?? (.All, .Take(numClusters))
        }
        var points = [Vector]()
        for row in 0..<eigenVcts.rows {
            points.append(Vector(eigenVcts[row: row]))
        }
        let labels = [Int](0...numClusters - 1)
        var predictedLabels: [Int]
        let kmeans = KMeans(labels: labels)
        var tentatives = 0
        repeat {
            predictedLabels = []
            kmeans.trainCenters(points, convergeDistance: 0.00001)
            for point in points {
                predictedLabels.append(kmeans.fit(point))
            }
            tentatives += 1
        } while Set(predictedLabels).count < eigenVals.count && tentatives <= 3

       return predictedLabels
    }

    /// This function returns the embedding of the given piece of text if the text is in English
    ///  and if the OS is at least MacOS 11 and iOS 14. Otherwise returns an empty vector.
    ///
    /// - Parameters:
    ///   - text: The text that will be turned into a contextual vector (embedding)
    /// - Returns: The embedding of the given piece of text as an optional.
    func textualEmbeddingComputationWithNLEmbedding(text: String) -> ([Double], NLLanguage)? {
        if let language = self.getTextLanguage(text: text),
           #available(iOS 14, macOS 11, *), language != NLLanguage.undetermined {
            if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english),
               let vector = sentenceEmbedding.vector(for: text) {
                    return (vector, language)
            }
        }

        return nil
    }

    func findEntitiesInText(text: String) -> EntitiesInText {
        var entitiesInCurrentText = EntitiesInText()
        self.tagger.string = text
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: entityOptions) { tag, tokenRange in
            // Get the most likely tag, and include it if it's a named entity.
            if let tag = tag, entityTags.contains(tag), let contains = entitiesInCurrentText.entities[tag.rawValue]?.contains(String(text[tokenRange]).lowercased()), contains == false {
                entitiesInCurrentText.entities[tag.rawValue]?.append(String(text[tokenRange]).lowercased())
            }
            return true
        }
        return entitiesInCurrentText
    }

    /// Compute the cosine similarity between two vectors
    ///
    /// - Parameters:
    ///   - vector1: a vector
    ///   - vector2: a vector
    /// - Returns: The cosine similarity between the two given vectors.
    func cosineSimilarity(vector1: [Double], vector2: [Double]) -> Double {
        let vec1Normed = cblas_dnrm2(Int32(vector1.count), vector1, 1)
        let vec2Normed = cblas_dnrm2(Int32(vector2.count), vector2, 1)
        let dotProduct = cblas_ddot(Int32(vector1.count), vector1, 1, vector2, 1)

        return dotProduct / (vec1Normed * vec2Normed)
    }

    /// This function detects the dominant language of a given text..
    ///
    /// - Parameters:
    ///   - text: The text from which the dominant language is detected
    /// - Returns: The dominant language.
    func getTextLanguage(text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }

    /// Compute the cosine similarity of the textual embedding of the current page against
    /// the other pages.
    ///
    /// - Parameters:
    ///   - textualEmbedding: the embedding of the current page
    /// - Returns: A list of cosine similarity scores
    func scoreTextualEmbedding(textualEmbedding: [Double], language: NLLanguage) -> [Double] {
        var scores = [Double]()

        for page in pages.dropLast() {
            // The textual vector might be empty, when the OS is not good or the page content is not in English
            // then the score will be 0.0
            if let textualVectorID = page.textEmbedding,
               let textLanguage = page.language,
               textLanguage ==  language {
                scores.append(self.cosineSimilarity(vector1: textualVectorID, vector2: textualEmbedding))
            } else {
                scores.append(1.0) // We don't want to "break" connections between langauges
            }
        }
        return scores
    }

    func scoreEntitySimilarities(entitiesInNewText: EntitiesInText, in whichText: FindEntitiesIn) -> [Double] {
        var scores = [Double]()
        switch whichText {
        case .content:
            for page in pages.dropLast() {
                if let entitiesInPage = page.entities {
                    scores.append(self.jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInPage))
                } else { scores.append(0.0) }
            }
        case .title:
            for page in pages.dropLast() {
                if let entitiesInPage = page.entitiesInTitle {
                    scores.append(self.jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInPage))
                } else { scores.append(0.0) }
            }

        }
        return scores
    }

    /// This function handles the entire textual similarity process:
    ///      - Compute the text embedding of the current page
    ///      - Compute the scores against all the other pages
    ///      - Add the scores into the final textual similarity matrix
    ///      - Complete the cache with the newly computed embedding
    ///
    /// - Parameters:
    ///   - pageIndex: the ID of the current page to process
    func textualSimilarityMatrixProcess(pageIndex: Int) throws {
        if let content = pages[pageIndex].content,
           let (textualEmbedding, language) = self.textualEmbeddingComputationWithNLEmbedding(text: content) {
                // if the OS is not good or the page content is not in English
                // we create a vector of only 0.0 scores
                let scores = self.scoreTextualEmbedding(textualEmbedding: textualEmbedding, language: language)
                try self.textualSimilarityMatrix.addPage(similarities: scores)
            self.pages[pageIndex].textEmbedding = textualEmbedding
            self.pages[pageIndex].language = language
        } else {
            try self.textualSimilarityMatrix.addPage(similarities: [Double](
                                                            repeating: 0.0,
                                                            count: self.textualSimilarityMatrix.matrix.rows
                                                        )
                                                    )
        }

    }

    func entitiesProcess(pageIndex: Int) throws {
        var scores = [Double](repeating: 0.0, count: self.entitiesMatrix.matrix.rows)
        if let content = pages[pageIndex].content {
            let entitiesInNewText = findEntitiesInText(text: content)
            scores = zip(scores, self.scoreEntitySimilarities(entitiesInNewText: entitiesInNewText, in: FindEntitiesIn.content)).map({ $0.0 + $0.1 })
            self.pages[pageIndex].entities = entitiesInNewText
        }
        if let title = pages[pageIndex].title {
            let entitiesInNewTitle = findEntitiesInText(text: title)
            scores = zip(scores, self.scoreEntitySimilarities(entitiesInNewText: entitiesInNewTitle, in: FindEntitiesIn.title)).map({ min($0.0 + $0.1, 1.0) })
            self.pages[pageIndex].entitiesInTitle = entitiesInNewTitle
        }
        try self.entitiesMatrix.addPage(similarities: scores)
    }

    func jaccardEntities(entitiesText1: EntitiesInText, entitiesText2: EntitiesInText) -> Double {
        var intersection: Set<String> = Set([String]())
        var union: Set<String> = Set([String]())
        var totalEntities1: Set<String> = Set([String]())
        var totalEntities2: Set<String> = Set([String]())

        for entityType in entitiesText1.entities.keys {
            union = Set(entitiesText1.entities[entityType] ?? [String]()).union(Set(entitiesText2.entities[entityType] ?? [String]())).union(union)
            intersection = Set(entitiesText1.entities[entityType] ?? [String]()).intersection(Set(entitiesText2.entities[entityType] ?? [String]())).union(intersection)
            totalEntities1 = Set(entitiesText1.entities[entityType] ?? [String]()).union(totalEntities1)
            totalEntities2 = Set(entitiesText2.entities[entityType] ?? [String]()).union(totalEntities2)
        }
        let minimumEntities = min(totalEntities1.count, totalEntities2.count)
        if minimumEntities > 0 {
            return Double(intersection.count) / Double(minimumEntities)
        } else {
            return 0
        }
        // if union.count > 0 {
        //     return Double(intersection.count) / Double(union.count)
        // } else {
        //     return 0.0
        // }
    }

    func findPageInPages(pageID: UInt64) -> Int? {
        let pageIDs = self.pages.map({ $0.id })
        return pageIDs.firstIndex(of: pageID)
    }

    /// This function receives a matrix and binarises it - all values above the
    ///  threshold are 1 and all values below are 0. The input matrix should only
    ///   have values between 0 and 1 (inclusive)
    ///
    /// - Parameters:
    ///   - matrix: The matrix to be binarised
    ///   - threshold: The threshold to be used
    /// - Returns
    ///   - binarised matrix

    func binarise(matrix: Matrix, threshold: Double) -> Matrix {
        // Bug in the thr() function in LASwift
        // let firstCompomemtMatrix = thr(matrix, threshold)
        // let secondComponentMatrix = -1 .* thr(firstCompomemtMatrix - 1, -0.99999)
        // return firstCompomemtMatrix + secondComponentMatrix
        let result = zeros(matrix.rows, matrix.cols)
        for row in 0..<matrix.rows {
            for column in 0..<matrix.cols {
                if matrix[row, column] > threshold {
                    result[row, column] = 1.0
                }
            }
        }
        return result
    }

    func createAdjacencyMatrix() {
        switch self.matrixCandidate {
        case .navigationMatrix:
            self.adjacencyMatrix = self.navigationMatrix.matrix
        case .navigationAndEntities:
            self.adjacencyMatrix = (self.weights["navigation"] ?? 0.5) .* self.navigationMatrix.matrix + (self.weights["entities"] ?? 0.5) * 8 .* self.entitiesMatrix.matrix
        case .textualSimilarityMatrix:
            self.adjacencyMatrix = self.textualSimilarityMatrix.matrix
        case .combinationAllSimilarityMatrix:
            self.adjacencyMatrix = (self.weights["text"] ?? 0.5) .*  self.textualSimilarityMatrix.matrix + (self.weights["entities"] ?? 0.5) .* self.entitiesMatrix.matrix + (self.weights["navigation"] ?? 0.5) .* self.navigationMatrix.matrix
        case .combinationAllBinarisedMatrix:
            self.adjacencyMatrix = self.binarise(matrix: self.navigationMatrix.matrix, threshold: (self.weights["navigation"] ?? 0.5)) + self.binarise(matrix: self.textualSimilarityMatrix.matrix, threshold: (weights["text"] ?? 0.5)) + self.binarise(matrix: self.entitiesMatrix.matrix, threshold: (weights["entities"] ?? 0.5))
        case .combinationBinarizedWithTextErasure:
            let textErasureMatrix = self.binarise(matrix: self.textualSimilarityMatrix.matrix, threshold: (weights["text"] ?? 0.5))
            self.adjacencyMatrix = textErasureMatrix .* self.binarise(matrix: self.navigationMatrix.matrix, threshold: (self.weights["navigation"] ?? 0.5)) + self.binarise(matrix: self.entitiesMatrix.matrix, threshold: (weights["entities"] ?? 0.5))
        }
    }

    func remove(ranking: [UInt64]) throws {
        var ranking = ranking
        var pagesRemoved = 0
        while pagesRemoved < 3 {
            if let pageToRemove = ranking.first {
                if let pageIndexToRemove = self.findPageInPages(pageID: pageToRemove) {
                    try self.navigationMatrix.removePage(index: pageIndexToRemove)
                    try self.textualSimilarityMatrix.removePage(index: pageIndexToRemove)
                    try self.entitiesMatrix.removePage(index: pageIndexToRemove)
                    self.pages.remove(at: pageIndexToRemove)
                    pagesRemoved += 1
                    ranking = Array(ranking.dropFirst())
                } else { ranking = Array(ranking.dropFirst()) }
            } else { break }
            self.createAdjacencyMatrix()
        }
    }

    func titlePreprocessing(of title: String) -> String {
        var preprocessedTitle = title
        for suffix in self.titleSuffixes {
            if preprocessedTitle.hasSuffix(suffix) {
                preprocessedTitle = String(preprocessedTitle.dropLast(suffix.count))
                break
            }
        }
        preprocessedTitle = preprocessedTitle.capitalized + " and some text"
        return preprocessedTitle
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func add(_ page: Page, ranking: [UInt64]?, completion: @escaping (Result<([[UInt64]], Bool), Error>) -> Void) {
        myQueue.async {
            // If ranking is received, remove pages
            if let ranking = ranking {
                do {
                    try self.remove(ranking: ranking)
                } catch let error {
                    completion(.failure(error))
                }
            }
            // Check if this is the first page in the session
            guard self.pages.count > 0 else {
                self.pages.append(page)

                if let content = self.pages[0].content {
                    if let (textualEmbedding, language) = self.textualEmbeddingComputationWithNLEmbedding(text: content) {
                        self.pages[0].textEmbedding = textualEmbedding
                        self.pages[0].language = language
                    }

                    self.pages[0].entities = self.findEntitiesInText(text: content)
                }
                if let title = self.pages[0].title {
                    let preprocessedTitle = self.titlePreprocessing(of: title)
                    self.pages[0].title = preprocessedTitle
                    self.pages[0].entitiesInTitle = self.findEntitiesInText(text: preprocessedTitle)
                }

                let result: [[UInt64]] = [[self.pages[0].id]]
                completion(.success((result, false)))
                return
            }
            if let id_index = self.findPageInPages(pageID: page.id) {
               if let myParent = page.parentId,
               let parent_index = self.findPageInPages(pageID: myParent) {
                    self.navigationMatrix.matrix[id_index, parent_index] = 1.0
                    self.navigationMatrix.matrix[parent_index, id_index] = 1.0
               }
            } else {
                // Navigation matrix computation
                var navigationSimilarities = [Double](repeating: 0.0, count: self.adjacencyMatrix.rows)

                if let myParent = page.parentId, let parent_index = self.findPageInPages(pageID: myParent) {
                    navigationSimilarities[parent_index] = 1.0
                }
                do {
                    try self.navigationMatrix.addPage(similarities: navigationSimilarities)
                } catch let error {
                    completion(.failure(error))
                }

                let newPageIndex = self.pages.count
                self.pages.append(page)
                if let title = self.pages[newPageIndex].title {
                    self.pages[newPageIndex].title = self.titlePreprocessing(of: title)
                }
                // Handle Text similarity matrix
                do {
                    try self.textualSimilarityMatrixProcess(pageIndex: newPageIndex)
                } catch let error {
                    completion(.failure(error))
                }

                // Handle entitites
                do {
                    try self.entitiesProcess(pageIndex: newPageIndex)
                } catch let error {
                    completion(.failure(error))
                }
            }
            //Here is where we would add more similarity matrices in the future
            self.createAdjacencyMatrix()

            let start = CFAbsoluteTimeGetCurrent()
            var predictedClusters = zeros(1, self.adjacencyMatrix.rows).flat.map { Int($0) }
            do {
                predictedClusters = try self.clusterize()
            } catch let error {
                completion(.failure(error))
            }
            let clusteringTime = CFAbsoluteTimeGetCurrent() - start
            let stablizedClusters = self.stabilize(predictedClusters)
            let result = self.clusterizeIDs(labels: stablizedClusters)

            DispatchQueue.main.async {
                if clusteringTime > self.timeToRemove {
                    completion(.success((result, true)))
                } else {
                    completion(.success((result, false)))
                }
            }
        }
    }

    func stabilize(_ predictedClusters: [Int]) -> [Int] {
        var nextNewCluster = 0
        var clustersMap = [Int: Int]()
        var newClusters = [Int]()
        for oldLabel in predictedClusters {
            if let newLabel = clustersMap[oldLabel] {
                newClusters.append(newLabel)
            } else {
                clustersMap[oldLabel] = nextNewCluster
                newClusters.append(nextNewCluster)
                nextNewCluster += 1
            }
        }
        return newClusters
    }

    private func clusterizeIDs(labels: [Int]) -> [[UInt64]] {
        guard self.pages.count > 0 else {
            return [[UInt64]]()
        }
        var nextCluster = 0
        var clusterized = [[UInt64]]()
        for label in labels.enumerated() {
            if label.element < nextCluster {
                clusterized[label.element].append(self.pages[label.offset].id)
            } else {
                clusterized.append([self.pages[label.offset].id])
                nextCluster += 1
            }
        }
        return clusterized
    }

    func performCandidateChange() throws {
        switch self.candidate {
        case 1:
            self.clusteringCandidate = ClusteringCandidate.nonNormalizedLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.navigationMatrix
            self.numClustersCandidate = NumClusterComputationCandidate.threshold
        case 2:
            self.clusteringCandidate = ClusteringCandidate.randomWalkLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.combinationAllBinarisedMatrix
            self.numClustersCandidate = NumClusterComputationCandidate.biggestDistanceInPercentages
        case 3:
            self.clusteringCandidate = ClusteringCandidate.randomWalkLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.combinationBinarizedWithTextErasure
            self.numClustersCandidate = NumClusterComputationCandidate.biggestDistanceInPercentages
        default:
            throw CandidateError.unknownCandidate
        }
    }
    public func changeCandidate(to candidate: Int?, with weightNavigation: Double?, with weightText: Double?, with weightEntities: Double?, completion: @escaping (Result<([[UInt64]], Bool), Error>) -> Void) {
        myQueue.async {
            // If ranking is received, remove pages
            self.candidate = candidate ?? self.candidate
            self.weights["navigation"] = weightNavigation ?? self.weights["navigation"]
            self.weights["text"] = weightText ?? self.weights["text"]
            self.weights["entities"] = weightEntities ?? self.weights["entities"]
            do {
                try self.performCandidateChange()
            } catch {
                completion(.failure(CandidateError.unknownCandidate))
            }

            self.createAdjacencyMatrix()
            var predictedClusters = zeros(1, self.adjacencyMatrix.rows).flat.map { Int($0) }
            do {
                predictedClusters = try self.clusterize()
            } catch let error {
                completion(.failure(error))
            }
            let stablizedClusters = self.stabilize(predictedClusters)
            let result = self.clusterizeIDs(labels: stablizedClusters)

            DispatchQueue.main.async {
                completion(.success((result, false)))
            }
        }
    }
    // swiftlint:disable:next file_length
}
