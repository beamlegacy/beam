//
//  Clustering.swift
//  Clustering
//
//  Created by Gil Katz on 17/05/2021.
//  Updated by Julien Plu on 06/01/2021 to add the textual similarity process.
//
//  Last updated: 06/03/2021
//

import LASwift
import Foundation
import NaturalLanguage
import Accelerate

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
}

public class Cluster {

    enum MatrixError: Error {
        case dimensionsNotMatching
        case matrixNotSquare
        case pageOutOfDimensions
    }

    enum CandidateError: Error {
        case unknownCandidte
    }
    
    enum MatrixTypeError: Error {
        case unknownMatrixType
    }

    public init() {}

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

        func removePage(pageNumber: Int) throws {
            guard matrix.rows == matrix.cols else {
              throw MatrixError.matrixNotSquare
            }
            guard pageNumber <= matrix.rows else {
              throw MatrixError.pageOutOfDimensions
            }
            switch pageNumber {
            case 0:
                self.matrix = self.matrix ?? (.Drop(1), .Drop(1))
            case self.matrix.rows - 1:
                self.matrix = self.matrix ?? (.DropLast(1), .DropLast(1))
            default:
                let upLeft = self.matrix ?? (.Take(pageNumber), .Take(pageNumber))
                let upRight = self.matrix ?? (.Take(pageNumber), .TakeLast(self.matrix.rows - pageNumber - 1))
                let downLeft = self.matrix ?? (.TakeLast(self.matrix.rows - pageNumber - 1), .Take(pageNumber))
                let downRight = self.matrix ?? (.TakeLast(self.matrix.rows - pageNumber - 1), .TakeLast(self.matrix.rows - pageNumber - 1))
                let left = upLeft === downLeft
                let right = upRight === downRight
                self.matrix = left ||| right
            }
        }
    }

   public class NavigationMatrix: SimilarityMatrix {
        override func removePage(pageNumber: Int) throws {
            var connectionsVct = (self.matrix ?? (.Pos([pageNumber]), .All)).flat
            connectionsVct.remove(at: pageNumber)
            try super.removePage(pageNumber: pageNumber)
            for i in 0..<self.matrix.rows where connectionsVct[i] == 1.0 {
                for j in 0..<self.matrix.rows where i != j && connectionsVct[j] == 1.0 {
                        self.matrix[i, j] = 1.0
                        self.matrix[j, i] = 1.0
                }
            }
        }
    }

    var candidate = 1
    // "navigation" to make the clustering based on the navigation, or "text" to make it based on textual similairty
    var matrixType = "navigation"
    let myQueue = DispatchQueue(label: "clusteringThread")
    var pageIDs = [UInt64]()
    var navigationMatrix = NavigationMatrix()
    var adjacencyMatrix = SimilarityMatrix()
    var textualSimilarityMatrix = SimilarityMatrix()
    var cacheTextualVectors: [UInt64: [Double]] = [:]

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func clusterize() throws -> [Int] {
        guard self.adjacencyMatrix.matrix.rows >= 2 else {
            return zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
        }
        let d = reduce(self.adjacencyMatrix.matrix, sum, .Row)
        let d1: [Double] = d.map { elem in
            if elem == 0.0 { return 0.0 } else { return 1 / elem }
        }
        let D = diag(d)
        let D1 = diag(d1)
        // This naming makes sense as D1 is 1/D
        let laplacianNn = D - self.adjacencyMatrix.matrix
        // This is the 'simplest' non-normalized Laplacian

        var laplacian: Matrix
        switch self.candidate { // This swith takes care of the choice of Laplacian
        case 1: // Non-normalised graph Laplacian
            laplacian = laplacianNn
        case 2: // Random-walk Laplacian
            laplacian = D1 * laplacianNn
        case 3: // Symmetric Laplacian
            laplacian = sqrt(D1) * laplacianNn * sqrt(D1)
        default:
            throw CandidateError.unknownCandidte
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
        switch self.candidate { // This switch takes care of the number of total classes
        case 1: // Threshold
            eigenVals.removeAll(where: { $0 > 1e-5 })
            numClusters = eigenVals.count
        case 2: // Biggest distance in percentages
            let eigenValsDifference = zip(eigenVals, eigenVals.dropFirst()).map { abs(($1 - $0) / $0) }
            let maxDifference = eigenValsDifference.max() ?? 0
            numClusters = (eigenValsDifference.lastIndex(of: maxDifference) ?? 0) + 1
        case 3: // Biggest distance, absolute
            let eigenValsDifference = zip(eigenVals, eigenVals.dropFirst()).map { abs(($1 - $0)) }
            let maxDifference = eigenValsDifference.max() ?? 0
            numClusters = (eigenValsDifference.lastIndex(of: maxDifference) ?? 0) + 1
        default:
            throw CandidateError.unknownCandidte
        }

        guard numClusters > 1 else {
            return zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
        }
        if eigenVcts.rows > numClusters {
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
    /// - Returns: The embedding of the given piece of text or an empty vector.
    func textualEmbeddingComputationWithNLEmbedding(text: String) -> [Double] {
        let language = self.getTextLanguage(text: text)
        
        if #available(iOS 14, macOS 11, *), language == NLLanguage.english {
            if let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) {
                if let vector = sentenceEmbedding.vector(for: text) {
                    return vector
                }
            }
        }
        
        return []
    }
    
    /// Compute the cosine similarity between two vectors
    ///
    /// - Parameters:
    ///   - vector1: a vector
    ///   - vector2: a vector
    /// - Returns: The cosine similarity between the two given vectors.
    func cosineSimilarity(vector1: inout [Double], vector2: inout [Double]) -> Double {
        let vec1Normed = cblas_dnrm2(Int32(vector1.count), &vector1, 1)
        let vec2Normed = cblas_dnrm2(Int32(vector2.count), &vector2, 1)
        let dotProduct = cblas_ddot(Int32(vector1.count), &vector1, 1, &vector2, 1)
        
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
    func scoreTextualEmbedding(textualEmbedding: inout [Double]) -> [Double] {
        var scores = [Double]()
        
        for id in self.pageIDs {
            // The textual vector might be empty, when the OS is not good or the page content is not in English
            // then the score will be 0.0
            if var textualVectorID = self.cacheTextualVectors[id] {
                if textualVectorID.isEmpty {
                    scores.append(0.0)
                } else {
                    scores.append(self.cosineSimilarity(vector1: &textualVectorID, vector2: &textualEmbedding))
                }
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
    ///   - page: the current page to process
    func textualSimilarityMatrixProcess(page: Page) throws {
        if let content = page.content {
            var textualEmbedding = self.textualEmbeddingComputationWithNLEmbedding(text: content)
            
            // if the OS is not good or the page content is not in English
            // we create a vector of only 0.0 scores
            if !textualEmbedding.isEmpty {
                let scores = self.scoreTextualEmbedding(textualEmbedding: &textualEmbedding)
                
                try self.textualSimilarityMatrix.addPage(similarities: scores)
            } else {
                try self.textualSimilarityMatrix.addPage(similarities: [Double](
                                                            repeating: 0.0,
                                                            count: self.textualSimilarityMatrix.matrix.rows)
                                                        )
            }
            // add the (id, textualEmbedding) to the cache
            self.cacheTextualVectors[page.id] = textualEmbedding
        } else {
            try self.textualSimilarityMatrix.addPage(similarities: [Double](
                                                        repeating: 0.0,
                                                        count: self.textualSimilarityMatrix.matrix.rows)
                                                    )
            self.cacheTextualVectors[page.id] = [Double]()
        }
    }

    public func add(_ page: Page, completion: @escaping (Result<[[UInt64]], Error>) -> Void) {
        myQueue.async {
            //Check if this is the first page in the session
            guard self.pageIDs.count > 0 else {
                self.pageIDs.append(page.id)
                
                if let content = page.content {
                    let textualEmbedding = self.textualEmbeddingComputationWithNLEmbedding(text: content)
                    self.cacheTextualVectors[page.id] = textualEmbedding
                }
                
                let result = [self.pageIDs]
                completion(.success(result))
                return
            }
            if let id_index = self.pageIDs.firstIndex(of: page.id) {
               if let myParent = page.parentId,
               let parent_index = self.pageIDs.firstIndex(of: myParent) {
                    self.navigationMatrix.matrix[id_index, parent_index] = 1.0
                    self.navigationMatrix.matrix[parent_index, id_index] = 1.0
               }
            } else {
                // AdjacencyMatrix computation
                var navigationSimilarities = [Double](repeating: 0.0, count: self.adjacencyMatrix.matrix.rows)
                
                if let myParent = page.parentId, let parent_index = self.pageIDs.firstIndex(of: myParent) {
                    navigationSimilarities[parent_index] = 1.0
                }
                do {
                    try self.navigationMatrix.addPage(similarities: navigationSimilarities)
                } catch let error {
                    completion(.failure(error))
                }
                
                // Handle Text similarity matrix
                do {
                    try self.textualSimilarityMatrixProcess(page: page)
                } catch let error {
                    completion(.failure(error))
                }
                
                self.pageIDs.append(page.id)
            }
            //Here is where we would add more similarity matrices in the future
            switch self.matrixType {
                case "navigation":
                    self.adjacencyMatrix.matrix = self.navigationMatrix.matrix
                case "text":
                    self.adjacencyMatrix.matrix = self.textualSimilarityMatrix.matrix
                default:
                    completion(.failure(MatrixTypeError.unknownMatrixType))
            }
            
            var predictedClusters = zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
            do {
                predictedClusters = try self.clusterize()
            } catch let error {
                completion(.failure(error))
            }
            let stablizedClusters = self.stabilize(predictedClusters)
            let result = self.clusterizeIDs(labels: stablizedClusters)
            
            DispatchQueue.main.async {
                completion(.success(result))
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
        var nextCluster = 0
        var clusterized = [[UInt64]]()
        for label in labels.enumerated() {
            if label.element < nextCluster {
                clusterized[label.element].append(self.pageIDs[label.offset])
            } else {
                clusterized.append([self.pageIDs[label.offset]])
                nextCluster += 1
            }
        }
        return clusterized
    }

    public func changeCandidate(to candidate: Int, completion: @escaping (Result<[[UInt64]], Error>) -> Void) {
        myQueue.async {
            self.candidate = candidate
            var predictedClusters = zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
            do {
                predictedClusters = try self.clusterize()
            } catch let error {
                completion(.failure(error))
            }
            let stablizedClusters = self.stabilize(predictedClusters)
            let result = self.clusterizeIDs(labels: stablizedClusters)

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }
    }
}
