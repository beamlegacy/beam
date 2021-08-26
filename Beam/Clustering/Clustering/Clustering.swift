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
    var attachedPages = [UInt64]()
}

public struct ClusteringNote {
    public init(id: UUID, title: String? = nil, content: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
    }
    var id: UUID
    var urls: [UInt64]? // These are urls from which content was actively
                        // added to the note.
    var title: String?
    var content: String?  // Text in the note.
                          // TODO: Should we save to source (copy-paste from a page, user input...)
    var textEmbedding: [Double]?
    var entities: EntitiesInText?
    var language: NLLanguage?
    var entitiesInTitle: EntitiesInText?
}

// swiftlint:disable:next type_body_length
public class Cluster {

    enum FindEntitiesIn {
        case content
        case title
    }

    enum AllWeights {
        case navigation
        case text
        case entities
    }

    enum DataPoint {
        case page
        case note
    }

    enum WhereToAdd {
        case first
        case last
        case middle
    }

    enum ClusteringCandidate {
        case nonNormalizedLaplacian
        case randomWalkLaplacian
        case symetricLaplacian
        case similarityMatrix
    }

    enum SimilarityMatrixCandidate {
        case navigationMatrix
        case combinationAllSimilarityMatrix
        case combinationAllBinarisedMatrix
        case combinationBinarizedWithTextErasure
        case combinationSigmoid
        case textualSimilarityMatrix
        case fixedPagesTestNotes
    }

    enum SimilarityForNotesCandidate {
        case nothing
        case fixed
        case combinationBeforeSigmoid
        case combinationAfterSigmoid
    }

    enum NumClusterComputationCandidate {
        case threshold
        case biggestDistanceInPercentages
        case biggestDistanceInAbsolute
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

    enum ClusteringError: Error {
        case moreThanOneObjectToAdd
        case noObjectsToAdd
    }

    let myQueue = DispatchQueue(label: "clusteringQueue")
    var pages = [Page]()
    var notes = [ClusteringNote]()
    // As the adjacency matrix is never touched on its own, just through the sub matrices, it
    // does not need add or remove methods.
    var adjacencyMatrix = Matrix([[0]])
    var navigationMatrix = NavigationMatrix()
    var textualSimilarityMatrix = SimilarityMatrix()
    var entitiesMatrix = SimilarityMatrix()
    let tagger = NLTagger(tagSchemes: [.nameType])
    let entityOptions: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
    let entityTags: [NLTag] = [.personalName, .placeName, .organizationName]
    var timeToRemove: Double = 0.5 // If clustering takes more than this (in seconds)
                                    // we start removing pages
    let titleSuffixes = [" - Google Search", " - YouTube"]
    let beta = 50.0

    var clusteringCandidate = ClusteringCandidate.nonNormalizedLaplacian
    // Define which similarity matrix to use
    var matrixCandidate = SimilarityMatrixCandidate.navigationMatrix
    var noteMatrixCandidate = SimilarityForNotesCandidate.fixed
    // Define which number of clusters computation to use
    var numClustersCandidate = NumClusterComputationCandidate.threshold
    var candidate: Int
    var weights = [AllWeights: Double]()

    public init(candidate: Int = 2, weightNavigation: Double = 0.5, weightText: Double = 0.5, weightEntities: Double = 0.5) {
        self.candidate = candidate
        self.weights[.navigation] = weightNavigation
        self.weights[.text] = weightText
        self.weights[.entities] = weightEntities
        do {
            try self.performCandidateChange()
        } catch {
            fatalError()
        }
    }

    public class SimilarityMatrix {
        var matrix = Matrix([[0]])

        func addDataPoint(similarities: [Double], type: DataPoint, numExistingNotes: Int, numExistingPages: Int) throws {

            guard matrix.rows == matrix.cols else {
              throw MatrixError.matrixNotSquare
            }
            guard matrix.rows == similarities.count else {
              throw MatrixError.dimensionsNotMatching
            }

            var whereToAdd: WhereToAdd?
            if numExistingPages == 0 && numExistingNotes == 0 {
                self.matrix = Matrix([[0]])
                return
            } else if type == .page || numExistingPages == 0 {
                whereToAdd = .last
            } else if numExistingNotes == 0 {
                whereToAdd = .first
            } else { // Adding a note, when there's already at least one note and one page
                whereToAdd = .middle
            }

            if let whereToAdd = whereToAdd {
                switch whereToAdd {
                case .first:
                    self.matrix = similarities ||| self.matrix
                    var similarities_row = similarities
                    similarities_row.insert(0.0, at: 0)
                    self.matrix = similarities_row === self.matrix
                case .last:
                    self.matrix = self.matrix ||| similarities
                    var similarities_row = similarities
                    similarities_row.append(0.0)
                    self.matrix = self.matrix === similarities_row
                case .middle:
                    let upLeft = self.matrix ?? (.Take(numExistingNotes), .Take(numExistingNotes))
                    let upRight = self.matrix ?? (.Take(numExistingNotes), .TakeLast(numExistingPages))
                    let downLeft = self.matrix ?? (.TakeLast(numExistingPages), .Take(numExistingNotes))
                    let downRight = self.matrix ?? (.TakeLast(numExistingPages), .TakeLast(numExistingPages))
                    let left = upLeft === (Array(similarities[0..<numExistingNotes]) === downLeft)
                    let right = upRight === (Array(similarities[numExistingNotes..<similarities.count]) === downRight)
                    var longSimilarities = similarities
                    longSimilarities.insert(0, at: numExistingNotes)
                    self.matrix = left ||| (longSimilarities ||| right)
                }
            }
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
            // if elem == 0.0 { return 0.0 } else { return 1 / elem }
            if elem < 1e-5 { return elem } else { return 1 / elem }
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
            if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: language),
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
        let languageToReturn = NLLanguageRecognizer.dominantLanguage(for: text)
        return languageToReturn // recognizer.dominantLanguage
    }

    /// Compute the cosine similarity of the textual embedding of the current page against
    /// the other pages.
    ///
    /// - Parameters:
    ///   - textualEmbedding: the embedding of the current page
    /// - Returns: A list of cosine similarity scores
    func scoreTextualEmbedding(textualEmbedding: [Double], language: NLLanguage, index: Int, dataPointType: DataPoint, changeContent: Bool = false) -> [Double] {
        var scores = [Double]()
         for note in notes.enumerated() {
            if dataPointType == . note {
                if !changeContent && note.offset == index && dataPointType == .note { break }
                scores.append(0.0)
            } else if let textualVectorID = note.element.textEmbedding,
                      let textLanguage = note.element.language,
                      textLanguage == language {
                scores.append(self.cosineSimilarity(vector1: textualVectorID, vector2: textualEmbedding))
            } else {
                scores.append(0.0)
            }

        }

        for page in pages.enumerated() {
            // The textual vector might be empty, when the OS is not good or the page content is not in English
            // then the score will be 0.0
            if page.offset == index && dataPointType == .page {
                if changeContent {
                    scores.append(0.0)
                } else { break }
            } else if let textualVectorID = page.element.textEmbedding,
                      let textLanguage = page.element.language,
                      textLanguage ==  language {
                    scores.append(self.cosineSimilarity(vector1: textualVectorID, vector2: textualEmbedding))
            } else if dataPointType == .page {
                scores.append(1.0) // We don't want to "break" connections between langauges
            } else {
                scores.append(0.0)
            }
        }
        return scores
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func scoreEntitySimilarities(entitiesInNewText: EntitiesInText, in whichText: FindEntitiesIn, index: Int, dataPointType: DataPoint, changeContent: Bool = false) -> [Double] {
        var scores = [Double]()
        switch whichText {
        case .content:
            for note in notes.enumerated() {
                if dataPointType == .note {
                    if !changeContent && note.offset == index && dataPointType == .note { break }
                    scores.append(0.0)
                } else if let entitiesInNote = note.element.entities {
                    scores.append(self.jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInNote))
                } else {
                    scores.append(0.0)
                }
            }
            for page in pages.enumerated() {
                if page.offset == index  && dataPointType == .page {
                    if changeContent {
                        scores.append(0.0)
                    } else { break }
                } else if let entitiesInPage = page.element.entities {
                    scores.append(self.jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInPage))
                } else { scores.append(0.0) }
            }
        case .title:
            for note in notes.enumerated() {
                if dataPointType == .note {
                    if !changeContent && note.offset == index && dataPointType == .note { break }
                    scores.append(0.0)
                } else if let entitiesInNoteTitle = note.element.entitiesInTitle {
                    scores.append(jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInNoteTitle))
                } else {
                    scores.append(0.0)
                }
            }
            for page in pages.enumerated() {
                if page.offset == index && dataPointType == .page {
                    if changeContent {
                        scores.append(0.0)
                    } else { break }
                } else if let entitiesInPage = page.element.entitiesInTitle {
                    scores.append(self.jaccardEntities(entitiesText1: entitiesInNewText, entitiesText2: entitiesInPage))
                } else { scores.append(0.0) }
            }
        }
        return scores
    }

    func textualSimilarityProcess(index: Int, dataPointType: DataPoint, changeContent: Bool = false) throws {
        var content: String?
        var scores = [Double](repeating: 0.0, count: self.textualSimilarityMatrix.matrix.rows)
        if dataPointType == .page {
            scores = [Double](repeating: 0.0, count: max(self.notes.count, 0))
            scores += [Double](repeating: 1.0, count: max(self.pages.count - 1, 0))
            if changeContent {
                scores.append(0.0)
            }
            content = pages[index].content
        } else {
            scores = [Double](repeating: 0.0, count: max(self.notes.count - 1, 0))
            scores += [Double](repeating: 1.0, count: max(self.pages.count, 0))
            if changeContent {
                scores.insert(1.0, at: 0)
            }
            content = notes[index].content
        }
        if let content = content,
           let (textualEmbedding, language) = self.textualEmbeddingComputationWithNLEmbedding(text: content) {
            scores = self.scoreTextualEmbedding(textualEmbedding: textualEmbedding, language: language, index: index, dataPointType: dataPointType, changeContent: changeContent)
            switch dataPointType {
            case .page:
                pages[index].textEmbedding = textualEmbedding
                pages[index].language = language
            case .note:
                notes[index].textEmbedding = textualEmbedding
                notes[index].language = language
            }
        }
        if changeContent {
            var indexToChange = index
            if dataPointType == .page {
                indexToChange += self.notes.count
            }
            self.textualSimilarityMatrix.matrix[row: indexToChange] = scores
            self.textualSimilarityMatrix.matrix[col: indexToChange] = scores
        } else if self.pages.count + self.notes.count > 1 {
            try self.textualSimilarityMatrix.addDataPoint(similarities: scores, type: dataPointType, numExistingNotes: max(self.notes.count - 1, 0), numExistingPages: self.pages.count)
        }
    }

    /// This function handles the entire textual similarity process:
    ///      - Compute the text embedding of the current page
    ///      - Compute the scores against all the other pages
    ///      - Add the scores into the final textual similarity matrix
    ///      - Complete the cache with the newly computed embedding
    ///
    /// - Parameters:
    ///   - pageIndex: the ID of the current page to process

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func entitiesProcess(index: Int, dataPointType: DataPoint, changeContent: Bool = false) throws {
        var scores = [Double](repeating: 0.0, count: self.entitiesMatrix.matrix.rows)
        var content: String?
        var title: String?
        switch dataPointType {
        case .page:
            content = self.pages[index].content
            title = self.pages[index].title
        case .note:
            content = self.notes[index].content
            title = self.notes[index].title
        }
        if let content = content {
            let entitiesInNewText = self.findEntitiesInText(text: content)
            scores = zip(scores, self.scoreEntitySimilarities(entitiesInNewText: entitiesInNewText, in: FindEntitiesIn.content, index: index, dataPointType: dataPointType, changeContent: changeContent)).map({ $0.0 + $0.1 })
            switch dataPointType {
            case .page:
                pages[index].entities = entitiesInNewText
            case .note:
                notes[index].entities = entitiesInNewText
            }
        }
        if let title = title {
            let entitiesInNewTitle = findEntitiesInText(text: title)
            scores = zip(scores, self.scoreEntitySimilarities(entitiesInNewText: entitiesInNewTitle, in: FindEntitiesIn.title, index: index, dataPointType: dataPointType, changeContent: changeContent)).map({ min($0.0 + $0.1, 1.0) })
            switch dataPointType {
            case .page:
                pages[index].entitiesInTitle = entitiesInNewTitle
            case .note:
                notes[index].entitiesInTitle = entitiesInNewTitle
            }
        }

        if changeContent {
            var indexToChange = index
            if dataPointType == .page {
                indexToChange += self.notes.count
            }
            self.entitiesMatrix.matrix[row: indexToChange] = scores
            self.entitiesMatrix.matrix[col: indexToChange] = scores
        } else if self.pages.count + self.notes.count > 1 {
            try self.entitiesMatrix.addDataPoint(similarities: scores, type: dataPointType, numExistingNotes: max(self.notes.count - 1, 0), numExistingPages: self.pages.count)
        }
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

    func findNoteInNotes(noteID: UUID) -> Int? {
        let noteIDs = self.notes.map({ $0.id })
        return noteIDs.firstIndex(of: noteID)
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

    /// This function receives a matrix and performs memberwise
    /// Sigmoid function over it
    ///
    /// - Parameters:
    ///   - matrix: The matrix to be binarised
    ///   - middle: The middle point of the Sigmoid function, where it equals 0.5
    ///   - beta: The steepness of the fumction
    ///
    /// - Returns
    ///   - binarised matrix
    func performSigmoidOn(matrix: Matrix, middle: Double, beta: Double) -> Matrix {
        return 1 ./ (1 + exp(-beta .* (matrix - middle)))
    }

    // swiftlint:disable:next cyclomatic_complexity
    func createAdjacencyMatrix() {
        switch self.matrixCandidate {
        case .navigationMatrix:
            self.adjacencyMatrix = self.navigationMatrix.matrix
        case .textualSimilarityMatrix:
            self.adjacencyMatrix = self.textualSimilarityMatrix.matrix
        case .combinationAllSimilarityMatrix:
            self.adjacencyMatrix = (self.weights[.text] ?? 0.5) .*  self.textualSimilarityMatrix.matrix + (self.weights[.entities] ?? 0.5) .* self.entitiesMatrix.matrix + (self.weights[.navigation] ?? 0.5) .* self.navigationMatrix.matrix
        case .combinationAllBinarisedMatrix:
            self.adjacencyMatrix = self.binarise(matrix: self.navigationMatrix.matrix, threshold: (self.weights[.navigation] ?? 0.5)) + self.binarise(matrix: self.textualSimilarityMatrix.matrix, threshold: (weights[.text] ?? 0.5)) + self.binarise(matrix: self.entitiesMatrix.matrix, threshold: (weights[.entities] ?? 0.5))
        case .combinationBinarizedWithTextErasure:
            let textErasureMatrix = self.binarise(matrix: self.textualSimilarityMatrix.matrix, threshold: (weights[.text] ?? 0.5))
            self.adjacencyMatrix = textErasureMatrix .* self.binarise(matrix: self.navigationMatrix.matrix, threshold: (self.weights[.navigation] ?? 0.5)) + self.binarise(matrix: self.entitiesMatrix.matrix, threshold: (weights[.entities] ?? 0.5))
        case .combinationSigmoid:
            let navigationSigmoidMatrix = self.performSigmoidOn(matrix: self.navigationMatrix.matrix, middle: self.weights[.navigation] ?? 0.5, beta: self.beta)
            let textSigmoidMatrix = self.performSigmoidOn(matrix: self.textualSimilarityMatrix.matrix, middle: self.weights[.text] ?? 0.5, beta: self.beta)
            let entitySigmoidMatrix = self.performSigmoidOn(matrix: self.entitiesMatrix.matrix, middle: self.weights[.entities] ?? 0.5, beta: self.beta)
            let adjacencyForPages = textSigmoidMatrix .* navigationSigmoidMatrix + entitySigmoidMatrix
            self.adjacencyMatrix = adjacencyForPages
        case .fixedPagesTestNotes:
            let navigationSigmoidMatrix = self.performSigmoidOn(matrix: self.navigationMatrix.matrix, middle: 0.5, beta: self.beta)
            let textSigmoidMatrix = self.performSigmoidOn(matrix: self.textualSimilarityMatrix.matrix, middle: 0.8, beta: self.beta)
            let entitySigmoidMatrix = self.performSigmoidOn(matrix: self.entitiesMatrix.matrix, middle: 0.3, beta: self.beta)
            let adjacencyForPages = textSigmoidMatrix .* navigationSigmoidMatrix + entitySigmoidMatrix
            self.adjacencyMatrix = adjacencyForPages
        }

        guard self.notes.count > 0 else { return }
        var adjacencyForNotes: Matrix?
        switch noteMatrixCandidate {
        case .nothing:
            break
        case .fixed:
            adjacencyForNotes = self.performSigmoidOn(matrix: self.textualSimilarityMatrix.matrix[0..<self.notes.count, 0..<self.textualSimilarityMatrix.matrix.cols] + self.entitiesMatrix.matrix[0..<self.notes.count, 0..<self.entitiesMatrix.matrix.cols], middle: 1, beta: self.beta)
        case .combinationAfterSigmoid:
            adjacencyForNotes = (self.weights[.text] ?? 0.5) .* self.performSigmoidOn(matrix: self.textualSimilarityMatrix.matrix[0..<self.notes.count, 0..<self.textualSimilarityMatrix.matrix.cols], middle: 1, beta: self.beta) + (self.weights[.entities] ?? 0.5) .* self.performSigmoidOn(matrix: self.entitiesMatrix.matrix[0..<self.notes.count, 0..<self.entitiesMatrix.matrix.cols], middle: (self.weights[.navigation] ?? 0.5) * 2, beta: beta)
        case .combinationBeforeSigmoid:
            adjacencyForNotes = self.performSigmoidOn(matrix: (self.weights[.text] ?? 0.5) .* self.textualSimilarityMatrix.matrix[0..<self.notes.count, 0..<self.textualSimilarityMatrix.matrix.cols] + (self.weights[.entities] ?? 0.5) .* self.entitiesMatrix.matrix[0..<self.notes.count, 0..<self.entitiesMatrix.matrix.cols], middle: (self.weights[.navigation] ?? 0.5) * 2, beta: self.beta)
        }

        if let adjacencyForNotes = adjacencyForNotes {
            self.adjacencyMatrix[0..<self.notes.count, 0..<self.adjacencyMatrix.cols] = adjacencyForNotes
            self.adjacencyMatrix[0..<self.adjacencyMatrix.rows, 0..<self.notes.count] = adjacencyForNotes.T
        }
    }

    func remove(ranking: [UInt64]) throws {
        var ranking = ranking
        var pagesRemoved = 0
        while pagesRemoved < 3 {
            if let pageToRemove = ranking.first {
                if let pageIndexToRemove = self.findPageInPages(pageID: pageToRemove) {
                    let adjacencyVector = self.adjacencyMatrix[row: pageIndexToRemove + self.notes.count]
                    if var pageIndexToAttach = adjacencyVector.firstIndex(of: max(adjacencyVector)) {
                        // TODO: Make sure that it can't be a note. Or the opposite - attach to a note!
                        pageIndexToAttach -= self.notes.count
                        pages[pageIndexToAttach].attachedPages.append(pageToRemove)
                        pages[pageIndexToAttach].attachedPages += pages[pageIndexToRemove].attachedPages
                    }
                    try self.navigationMatrix.removePage(index: pageIndexToRemove + self.notes.count)
                    try self.textualSimilarityMatrix.removePage(index: pageIndexToRemove + self.notes.count)
                    try self.entitiesMatrix.removePage(index: pageIndexToRemove + self.notes.count)
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

    func removeFromDeleted(newPageID: UInt64) {
        for page in self.pages.enumerated() {
            pages[page.offset].attachedPages = page.element.attachedPages.filter {$0 != newPageID}
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length large_tuple
    public func add(page: Page? = nil, note: ClusteringNote? = nil, ranking: [UInt64]?, replaceContent: Bool = false, completion: @escaping (Result<(pageGroups: [[UInt64]], noteGroups: [[UUID]], sendRanking: Bool), Error>) -> Void) {
        myQueue.async {
            // Check that we are adding exactly one object
            if page != nil && note != nil {
                completion(.failure(ClusteringError.moreThanOneObjectToAdd))
                return
            }
            if page == nil && note == nil {
                completion(.failure(ClusteringError.noObjectsToAdd))
                return
            }
            var dataPointType: DataPoint = .note
            if page != nil {
                dataPointType = .page
            }
            // If ranking is received, remove pages
            if let ranking = ranking {
                do {
                    try self.remove(ranking: ranking)
                } catch let error {
                    completion(.failure(error))
                }
            }
            // PnS text addition (only available for pages)
            if let page = page,
               let id_index = self.findPageInPages(pageID: page.id) {
                if replaceContent,
                   let newContent = page.content {
                    let totalContentTokenized = (newContent + " " + (self.pages[id_index].content ?? "")).split(separator: " ")
                    if totalContentTokenized.count > 512 {
                        self.pages[id_index].content = totalContentTokenized.dropLast(totalContentTokenized.count - 512).joined(separator: " ")
                    } else {
                        self.pages[id_index].content = totalContentTokenized.joined(separator: " ")
                    }
                    do {
                        try self.textualSimilarityProcess(index: id_index, dataPointType: dataPointType, changeContent: true)
                        try self.entitiesProcess(index: id_index, dataPointType: dataPointType, changeContent: true)
                    } catch let error {
                        completion(.failure(error))
                    }
            // Page exists, new parenting relation
               }
               if let myParent = page.parentId,
               let parent_index = self.findPageInPages(pageID: myParent) {
                self.navigationMatrix.matrix[id_index + self.notes.count, parent_index + self.notes.count] = 1.0
                self.navigationMatrix.matrix[parent_index + self.notes.count, id_index + self.notes.count] = 1.0
               }
            // Updating existing note
            } else if let note = note,
                      let id_index = self.findNoteInNotes(noteID: note.id) {
                do {
                    if let newContent = note.content {
                        self.notes[id_index].content = newContent
                    }
                    if let newTitle = note.title {
                        self.notes[id_index].title = self.titlePreprocessing(of: newTitle)
                    }
                    try self.textualSimilarityProcess(index: id_index, dataPointType: .note, changeContent: true)
                    try self.entitiesProcess(index: id_index, dataPointType: .note, changeContent: true)
                } catch let error {
                    completion(.failure(error))
                }
            // New page or note
            } else {
                // If page was visited in the past and deleted, remove from
                // deleted pages
                if let page = page {
                    self.removeFromDeleted(newPageID: page.id)
                }
                // Navigation matrix computation
                var navigationSimilarities = [Double](repeating: 0.0, count: self.adjacencyMatrix.rows)

                if let page = page, let myParent = page.parentId, let parent_index = self.findPageInPages(pageID: myParent) {
                    navigationSimilarities[parent_index + self.notes.count] = 1.0
                }

                do {
                    try self.navigationMatrix.addDataPoint(similarities: navigationSimilarities, type: dataPointType, numExistingNotes: self.notes.count, numExistingPages: self.pages.count)
                } catch let error {
                    completion(.failure(error))
                }

                var newIndex = self.pages.count
                if let page = page {
                    self.pages.append(page)
                    if let title = self.pages[newIndex].title {
                        self.pages[newIndex].title = self.titlePreprocessing(of: title)
                    }
                } else if let note = note {
                    newIndex = self.notes.count
                    self.notes.append(note)
                    if let title = self.notes[newIndex].title {
                        self.notes[newIndex].title = self.titlePreprocessing(of: title)
                    }
                }
                // Handle Text similarity and entities
                do {
                    try self.textualSimilarityProcess(index: newIndex, dataPointType: dataPointType)
                    try self.entitiesProcess(index: newIndex, dataPointType: dataPointType)
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
            let (resultPages, resultNotes) = self.clusterizeIDs(labels: stablizedClusters)

            DispatchQueue.main.async {
                if clusteringTime > self.timeToRemove {
                    completion(.success((pageGroups: resultPages, noteGroups: resultNotes, sendRanking: true)))
                } else {
                    completion(.success((pageGroups: resultPages, noteGroups: resultNotes, sendRanking: false)))
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

    private func clusterizeIDs(labels: [Int]) -> ([[UInt64]], [[UUID]]) {
        guard self.notes.count + self.pages.count > 0 else { return ([[UInt64]](), [[UUID]]())}

        var clusterizedPages = [[UInt64]]()
        if labels.count > 0 {
            for _ in 0...(labels.max() ?? 0) {
                clusterizedPages.append([UInt64]())
            }
        }
        var clusterizedNotes = [[UUID]]()
        if labels.count > 0 {
            for _ in 0...(labels.max() ?? 0) {
                clusterizedNotes.append([UUID]())
            }
        }

        for label in labels.enumerated() {
            if label.offset < self.notes.count {
                clusterizedNotes[label.element].append(self.notes[label.offset].id)
            } else {
                clusterizedPages[label.element].append(self.pages[label.offset - self.notes.count].id)
                clusterizedPages[label.element] += self.pages[label.offset - self.notes.count].attachedPages
            }
        }
        return (clusterizedPages, clusterizedNotes)
    }

    func performCandidateChange() throws {
        switch self.candidate {
        case 1:
            self.clusteringCandidate = ClusteringCandidate.nonNormalizedLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.navigationMatrix
            self.noteMatrixCandidate = SimilarityForNotesCandidate.nothing
            self.numClustersCandidate = NumClusterComputationCandidate.threshold
        case 2:
            self.clusteringCandidate = ClusteringCandidate.randomWalkLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.combinationSigmoid
            self.noteMatrixCandidate = SimilarityForNotesCandidate.fixed
            self.numClustersCandidate = NumClusterComputationCandidate.biggestDistanceInPercentages
        case 3:
            self.clusteringCandidate = ClusteringCandidate.randomWalkLaplacian
            self.matrixCandidate = SimilarityMatrixCandidate.fixedPagesTestNotes
            self.noteMatrixCandidate = SimilarityForNotesCandidate.combinationBeforeSigmoid
            self.numClustersCandidate = NumClusterComputationCandidate.biggestDistanceInPercentages
        default:
            throw CandidateError.unknownCandidate
        }
    }
    // swiftlint:disable:next large_tuple
    public func changeCandidate(to candidate: Int?, with weightNavigation: Double?, with weightText: Double?, with weightEntities: Double?, completion: @escaping (Result<(pageGroups: [[UInt64]], noteGroups: [[UUID]], sendRanking: Bool), Error>) -> Void) {
        myQueue.async {
            // If ranking is received, remove pages
            self.candidate = candidate ?? self.candidate
            self.weights[.navigation] = weightNavigation ?? self.weights[.navigation]
            self.weights[.text] = weightText ?? self.weights[.text]
            self.weights[.entities] = weightEntities ?? self.weights[.entities]
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
            let (resultPages, resultNotes) = self.clusterizeIDs(labels: stablizedClusters)

            DispatchQueue.main.async {
                completion(.success((pageGroups: resultPages, noteGroups: resultNotes, sendRanking: false)))
            }
        }
    }
    // swiftlint:disable:next file_length
}
