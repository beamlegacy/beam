//
//  Clustering.swift
//  Clustering
//
//  Created by Gil Katz on 17/05/2021.
//

import LASwift
import Foundation

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

    let myThread = DispatchQueue(label: "clusteringThread")
    var pageIDs = [UInt64]()
    var navigationMatrix = NavigationMatrix()
    var adjacencyMatrix = SimilarityMatrix()

    func clusterize() -> [Int] {
        guard self.adjacencyMatrix.matrix.rows >= 2 else {
            return zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
        }
        let laplacian = diag(reduce(self.adjacencyMatrix.matrix, sum, .Row)) - self.adjacencyMatrix.matrix
        //TODO: Add other types of graph Laplacians

        let eigen = eig(laplacian)
        var eigenVals = reduce(eigen.D, sum)
        let indices = eigenVals.indices
        let combined = zip(eigenVals, indices).sorted { $0.0 < $1.0 }
        eigenVals = combined.map { $0.0 }
        let permutation = combined.map { $0.1 }
        var eigenVcts = eigen.V ?? (.All, .Pos(permutation))

        eigenVals.removeAll(where: { $0 > 1e-5 })
        //TODO: Integrate more sophisticated rules to choose relevant eigenvalues

        guard eigenVals.count > 1 else {
            return zeros(1, self.adjacencyMatrix.matrix.rows).flat.map { Int($0) }
        }
        if eigenVcts.rows > eigenVals.count {
            eigenVcts = eigenVcts ?? (.All, .DropLast(eigenVcts.rows - eigenVals.count))
        }
        var points = [Vector]()
        for row in 0..<eigenVcts.rows {
            points.append(Vector(eigenVcts[row: row]))
        }
        let labels = [Int](0...eigenVals.count - 1)
        var predictedLabels: [Int]
        let kmeans = KMeans(labels: labels)
        var tentatives = 0
        repeat {
            predictedLabels = []
            kmeans.trainCenters(points, convergeDistance: 0.000001)
            for point in points {
                predictedLabels.append(kmeans.fit(point))
            }
            tentatives += 1
        } while Set(predictedLabels).count < eigenVals.count && tentatives <= 10
       return predictedLabels
    }

    public func add(_ page: Page, completion: @escaping (Result<[[UInt64]], Error>) -> Void) {
        myThread.async {
            //Check if this is the first page in the session
            guard self.pageIDs.count > 0 else {
                self.pageIDs.append(page.id)
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
                var navigationSimilarities = [Double](repeating: 0.0, count: self.adjacencyMatrix.matrix.rows)
                self.pageIDs.append(page.id)
                if let myParent = page.parentId, let parent_index = self.pageIDs.firstIndex(of: myParent) {
                    navigationSimilarities[parent_index] = 1.0
                }
                do {
                    try self.navigationMatrix.addPage(similarities: navigationSimilarities)
                } catch let error {
                    completion(.failure(error))
                }
            }
            //Here is where we would add more similarity matrices in the future
            self.adjacencyMatrix.matrix = self.navigationMatrix.matrix

            let predictedClusters = self.clusterize()
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
}
