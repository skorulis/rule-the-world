import MapKit
import UIKit

final class UserStatusAnnotationView: UIView {
    private static let size: CGFloat = 120
    private static let orbitRadius: CGFloat = 34
    private static let speedLabelOffset: CGFloat = 36

    private let arrowView = UIImageView()
    private let speedLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)

        arrowView.image = UIImage(systemName: "location.north.fill")
        arrowView.tintColor = .systemBlue
        arrowView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22)
        arrowView.sizeToFit()
        addSubview(arrowView)

        speedLabel.font = UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize)
        speedLabel.textColor = .white
        speedLabel.textAlignment = .center
        speedLabel.backgroundColor = .systemBlue
        speedLabel.layer.cornerRadius = 8
        speedLabel.layer.masksToBounds = true
        addSubview(speedLabel)

        autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(status: UserMapStatus, mapHeading: CLLocationDirection) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if let direction = status.directionDegrees {
            arrowView.isHidden = false
            let radians = (direction - mapHeading) * .pi / 180
            arrowView.transform = .identity
            arrowView.center = CGPoint(
                x: center.x + Self.orbitRadius * sin(radians),
                y: center.y - Self.orbitRadius * cos(radians)
            )
            arrowView.transform = CGAffineTransform(rotationAngle: radians)
        } else {
            arrowView.isHidden = true
        }
        if let speed = status.speedKmh, Int(speed.rounded()) > 0 {
            speedLabel.isHidden = false
            speedLabel.text = "\(Int(speed.rounded())) km/h"
            speedLabel.sizeToFit()
            speedLabel.bounds.size.width += 12
            speedLabel.bounds.size.height += 4
            speedLabel.center = CGPoint(x: center.x, y: center.y + Self.speedLabelOffset)
        } else {
            speedLabel.isHidden = true
        }
    }
}
