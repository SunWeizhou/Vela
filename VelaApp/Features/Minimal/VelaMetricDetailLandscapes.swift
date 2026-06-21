import SwiftUI

struct MetricLandscapeHeader: View {
    let metric: VelaMetricDetailView.MetricType
    let isSleep: Bool
    
    var body: some View {
        Group {
            switch metric {
            case .strain:
                DesertLandscape()
            case .sleep:
                NightLandscape()
            case .stress:
                CoastalLandscape()
            case .recovery:
                ForestLandscape()
            case .energy:
                MeadowLandscape()
            case .hrv:
                MountainLakeLandscape()
            case .rhr:
                CalmSunsetLandscape()
            case .weight:
                MeadowLandscape()
            case .bodyFat:
                MeadowLandscape()
            case .respiratoryRate:
                MountainLakeLandscape()
            case .bloodOxygen:
                CalmSunsetLandscape()
            case .steps:
                MeadowLandscape()
            case .activeCalories:
                DesertLandscape()
            case .activeMinutes:
                CoastalLandscape()
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
    }
}

struct DesertLandscape: View {
    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [Color(hex: "#D2E7F9"), Color(hex: "#F5E6D8"), Color(hex: "#FFF6E5")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Distant soft orange sun
            Circle()
                .fill(Color(hex: "#FFDDA1").opacity(0.8))
                .frame(width: 60, height: 60)
                .blur(radius: 6)
                .offset(x: -40, y: -20)
            
            // Sand dunes
            Path { path in
                path.move(to: CGPoint(x: 0, y: 160))
                path.addQuadCurve(to: CGPoint(x: 180, y: 170), control: CGPoint(x: 90, y: 140))
                path.addQuadCurve(to: CGPoint(x: 400, y: 190), control: CGPoint(x: 290, y: 200))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#EFECE7"), Color(hex: "#E5DFD5")], startPoint: .top, endPoint: .bottom))
            
            Path { path in
                path.move(to: CGPoint(x: 160, y: 190))
                path.addQuadCurve(to: CGPoint(x: 400, y: 170), control: CGPoint(x: 280, y: 210))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 160, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#E9E3D9"), Color(hex: "#DFD7C9")], startPoint: .top, endPoint: .bottom))
            
            // Joshua Trees Vector Outline on the right
            MinimalistJoshuaTree(xOffset: 120, scale: 0.85)
            MinimalistJoshuaTree(xOffset: 145, scale: 0.65)
        }
    }
}

struct NightLandscape: View {
    var body: some View {
        ZStack {
            // Midnight sky gradient
            LinearGradient(
                colors: [Color(hex: "#090814"), Color(hex: "#0F0D24"), Color(hex: "#1B173B")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Stars
            RandomStar(x: 30, y: 40, size: 2, opacity: 0.8)
            RandomStar(x: 80, y: 60, size: 3, opacity: 0.5)
            RandomStar(x: 120, y: 30, size: 1.5, opacity: 0.9)
            RandomStar(x: 240, y: 50, size: 2.5, opacity: 0.6)
            RandomStar(x: 290, y: 80, size: 2, opacity: 0.4)
            RandomStar(x: 340, y: 35, size: 3, opacity: 0.8)
            
            // Soft moon
            Circle()
                .fill(Color(hex: "#F5F3ED").opacity(0.12))
                .frame(width: 80, height: 80)
                .blur(radius: 4)
                .offset(x: -120, y: -40)
            
            // Mountain Peak Silhouettes at bottom
            Path { path in
                path.move(to: CGPoint(x: 0, y: 170))
                path.addLine(to: CGPoint(x: 120, y: 120))
                path.addLine(to: CGPoint(x: 260, y: 190))
                path.addLine(to: CGPoint(x: 340, y: 150))
                path.addLine(to: CGPoint(x: 400, y: 190))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#0D0A1E"), Color(hex: "#05030B")], startPoint: .top, endPoint: .bottom))
            
            Path { path in
                path.move(to: CGPoint(x: 80, y: 185))
                path.addLine(to: CGPoint(x: 210, y: 140))
                path.addLine(to: CGPoint(x: 320, y: 200))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 80, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#0A0818"), Color(hex: "#030206")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct CoastalLandscape: View {
    var body: some View {
        ZStack {
            // Calm Sky
            LinearGradient(
                colors: [Color(hex: "#E4F0FB"), Color(hex: "#FFF4ED"), Color(hex: "#FFF1DB")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Soft white setting sun
            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: 50, height: 50)
                .blur(radius: 5)
                .offset(x: -80, y: 0)

            // Rocky sea cliffs on the right
            Path { path in
                path.move(to: CGPoint(x: 220, y: 240))
                path.addLine(to: CGPoint(x: 270, y: 140))
                path.addLine(to: CGPoint(x: 300, y: 160))
                path.addLine(to: CGPoint(x: 350, y: 80))
                path.addLine(to: CGPoint(x: 400, y: 100))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#9AB2C5"), Color(hex: "#7A92A5")], startPoint: .top, endPoint: .bottom))
            
            // Coastal waves at bottom
            Path { path in
                path.move(to: CGPoint(x: 0, y: 190))
                path.addQuadCurve(to: CGPoint(x: 180, y: 200), control: CGPoint(x: 90, y: 215))
                path.addQuadCurve(to: CGPoint(x: 400, y: 175), control: CGPoint(x: 290, y: 180))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#90D1DB"), Color(hex: "#5DB8CA"), Color(hex: "#349BB0")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct ForestLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E3F3EA"), Color(hex: "#FFFEE8")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Green forest silhouette
            Path { path in
                path.move(to: CGPoint(x: 0, y: 200))
                path.addQuadCurve(to: CGPoint(x: 200, y: 180), control: CGPoint(x: 100, y: 210))
                path.addQuadCurve(to: CGPoint(x: 400, y: 190), control: CGPoint(x: 300, y: 170))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#84B094"), Color(hex: "#5C8C6F")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct MeadowLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#D6F2FE"), Color(hex: "#FFF4CE")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Sunny spring meadows
            Path { path in
                path.move(to: CGPoint(x: 0, y: 180))
                path.addQuadCurve(to: CGPoint(x: 400, y: 170), control: CGPoint(x: 200, y: 210))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#D6BF74"), Color(hex: "#BFA456")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct MountainLakeLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#DDF4FE"), Color(hex: "#ECE8FF")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Serene lake reflection peaks
            Path { path in
                path.move(to: CGPoint(x: 0, y: 190))
                path.addQuadCurve(to: CGPoint(x: 200, y: 205), control: CGPoint(x: 100, y: 175))
                path.addQuadCurve(to: CGPoint(x: 400, y: 185), control: CGPoint(x: 300, y: 215))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#87BAC5"), Color(hex: "#6A9AA5")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct CalmSunsetLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFE4D5"), Color(hex: "#FFC8B3")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Calm evening wave dunes
            Path { path in
                path.move(to: CGPoint(x: 0, y: 195))
                path.addQuadCurve(to: CGPoint(x: 400, y: 195), control: CGPoint(x: 200, y: 220))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#E89B7D"), Color(hex: "#0A84FF")], startPoint: .top, endPoint: .bottom))
        }
    }
}

// Minimal Joshua Tree outline helper
struct MinimalistJoshuaTree: View {
    let xOffset: CGFloat
    let scale: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let startX = w - xOffset
            let startY = h - 60
            
            Path { path in
                // Trunk
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: startX, y: startY - (40 * scale)))
                
                // Branch left
                path.move(to: CGPoint(x: startX, y: startY - (30 * scale)))
                path.addLine(to: CGPoint(x: startX - (15 * scale), y: startY - (42 * scale)))
                path.addLine(to: CGPoint(x: startX - (15 * scale), y: startY - (55 * scale)))
                
                // Branch right
                path.move(to: CGPoint(x: startX, y: startY - (35 * scale)))
                path.addLine(to: CGPoint(x: startX + (12 * scale), y: startY - (45 * scale)))
                path.addLine(to: CGPoint(x: startX + (12 * scale), y: startY - (60 * scale)))
            }
            .stroke(Color(hex: "#4A433A"), style: StrokeStyle(lineWidth: 3.5 * scale, lineCap: .round, lineJoin: .round))
            
            // Foliage pom-poms (vector circles)
            Group {
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 14 * scale, height: 14 * scale)
                    .position(x: startX, y: startY - (45 * scale))
                
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 12 * scale, height: 12 * scale)
                    .position(x: startX - (15 * scale), y: startY - (55 * scale))
                
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 13 * scale, height: 13 * scale)
                    .position(x: startX + (12 * scale), y: startY - (60 * scale))
            }
        }
    }
}

struct RandomStar: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.8), radius: size * 1.2)
            .position(x: x, y: y)
    }
}
