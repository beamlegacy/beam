import Foundation

class ShootFrameFusionRect {
    var minX: CGFloat = CGFloat.greatestFiniteMagnitude
    var minY: CGFloat = CGFloat.greatestFiniteMagnitude
    var maxX: CGFloat = -CGFloat.greatestFiniteMagnitude
    var maxY: CGFloat = -CGFloat.greatestFiniteMagnitude

    func getRect(targets: [PointAndShoot.Target]) -> CGRect {
        targets.forEach { (selection) in
            let rect = selection.rect
            if rect.minX < minX {
                minX = rect.minX
            }
            if rect.minY < minY {
                minY = rect.minY
            }
            if rect.maxX > maxX {
                maxX = rect.maxX
            }
            if rect.maxY > maxY {
                maxY = rect.maxY
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
