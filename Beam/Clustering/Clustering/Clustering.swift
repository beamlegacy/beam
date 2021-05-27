//
//  Clustering.swift
//  Clustering
//
//  Created by Gil Katz on 17/05/2021.
//

import LASwift
import Foundation

class Cluster {
    
    enum MatrixError: Error {
        case dimensionsNotMatching
        case matrixNotSquare
        case pageOutOfDimensions
    }
    
    class SimilarityMatrix {
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
    
    class NavigationMatrix: SimilarityMatrix {
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
    
    var pageIDs = [UUID]()
    var navigationMatrix = NavigationMatrix()
    var adjacencyMatrix = SimilarityMatrix()
    var clusters = [Int]()
    
    func clusterize() {
        guard self.adjacencyMatrix.matrix.rows >= 2 else {
          self.clusters = zeros(1, self.adjacencyMatrix.matrix.rows).flat.map({Int($0)})
          return
        }
        let laplacian = diag(reduce(self.adjacencyMatrix.matrix, sum, .Row)) - self.adjacencyMatrix.matrix
        //TODO: Add other types of graph Laplacians
        
        let eigen = eig(laplacian)
        var eigenVals = reduce(eigen.D, sum)
        let indeces = eigenVals.indices
        let combined = zip(eigenVals, indeces).sorted {$0.0 < $1.0}
        eigenVals = combined.map {$0.0}
        let permutation = combined.map {$0.1}
        var eigenVcts = eigen.V ?? (.All, .Pos(permutation))
        
        eigenVals.removeAll(where: {$0 > 1e-5})
        //TODO: Integrate more sophisticated rules to choose relevant eigenvalues
        
        guard eigenVals.count > 1 else {
            self.clusters = zeros(1, self.adjacencyMatrix.matrix.rows).flat.map({Int($0)})
            return
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
        clusters = predictedLabels
    }
    
    func addPage(id: UUID, from parent: UUID?) throws {
        //Check if this is the first page in the session
        guard pageIDs.count > 0 else {
            pageIDs.append(id)
            clusters = [0]
            return
        }
        if let id_index = pageIDs.firstIndex(of: id) {
            if let myParent = parent , let parent_index = pageIDs.firstIndex(of: myParent) {
                self.navigationMatrix.matrix[id_index, parent_index] = 1.0
                self.navigationMatrix.matrix[parent_index, id_index] = 1.0
            }
        } else {
            var navigationSimilarities = [Double](repeating: 0.0, count: self.adjacencyMatrix.matrix.rows)
            pageIDs.append(id)
            if let myParent = parent, let parent_index = pageIDs.firstIndex(of: myParent) {
                navigationSimilarities[parent_index] = 1.0
            }
            try self.navigationMatrix.addPage(similarities: navigationSimilarities)
        }
        //Here is where we would add more similarity matrices in the future
        self.adjacencyMatrix.matrix = self.navigationMatrix.matrix
        
        self.clusterize()
        self.stabeliseClusters()
    }
    
    func stabeliseClusters () {
        var nextNewCluster = 0
        var clustersMap = [Int: Int]()
        var newClusters = [Int]()
        for oldLabel in self.clusters {
            if let newLabel = clustersMap[oldLabel] {
                newClusters.append(newLabel)
            } else {
                clustersMap[oldLabel] = nextNewCluster
                newClusters.append(nextNewCluster)
                nextNewCluster += 1
            }
        }
        self.clusters = newClusters
    }
}
