import SwiftUI
import UIKit

struct TodaysScoreParticlesView: View {
    @ObservedObject var viewModel: ReadinessViewModel
    @Environment(\.appearanceViewModel) private var appearanceViewModel
    @AppStorage("readinessMode") private var readinessMode: String = "morning"
    @State private var isAnimating = false
    @State private var isTapped = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 300, height: 300)
            
            if appearanceViewModel.showParticles && !UIAccessibility.isReduceMotionEnabled {
                // Particle System
                ParticleSystem(
                    readinessScore: viewModel.readinessScore,
                    categoryColor: viewModel.readinessColor,
                    isAnimating: isAnimating,
                    isTapped: isTapped
                )
                .frame(width: 300, height: 300)
                .clipShape(Circle())
            }
            
            // Central Core (always shown)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [viewModel.readinessColor.opacity(0.1), viewModel.readinessColor.opacity(0.3)]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 300
                    )
                )
                .frame(width: 300, height: 300)
        }
        .frame(maxWidth: .infinity)
        .background(.clear)
        .onTapGesture {
            // Only animate if particles are enabled and reduce motion is off
            if appearanceViewModel.showParticles && !UIAccessibility.isReduceMotionEnabled {
                withAnimation {
                    isTapped = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        isTapped = false
                    }
                }
            }
        }
        .onChange(of: viewModel.readinessScore) { _, _ in
            // Reset and restart animation when score changes
            withAnimation {
                isAnimating = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isAnimating = true
                }
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                isAnimating = true
            }
        }
    }
}

// Particle representation
struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var scale: CGFloat
    var opacity: Double
    var color: Color
    var lifespan: Double // Particle lifespan in seconds
    var birthTime: Date // When the particle was created
    var energyLevel: Double // Energy level for random behavior
    var isExpanding: Bool = false // Whether the particle is in expansion mode after tap
    var expansionScale: CGFloat = 1.0 // Scale multiplier during expansion
}

// Particle System component
struct ParticleSystem: View {
    let readinessScore: Double
    let categoryColor: Color
    let isAnimating: Bool
    let isTapped: Bool
    
    @State private var particles: [Particle] = []
    @State private var lastUpdateTime: Date = Date()
    @State private var isInitialized = false
    
    // Parameters affected by readiness score
    private var particleCount: Int {
        // Higher score = more particles
        Int(max(45, readinessScore * 1.2))
    }
    
    private var particleSpeed: Double {
        // Lower score = faster movement (more chaotic)
        max(0.8, 2.0 - (readinessScore / 50))
    }
    
    private var orbitStability: Double {
        // Higher score = more stable orbit
        readinessScore / 100
    }
    
    private var gravitationalForce: Double {
        // Lower score = stronger gravitational pull (but more chaotic)
        0.2 * (1.0 - orbitStability)
    }
    
    private var particleLifespan: ClosedRange<Double> {
        // Particle lifespan range in seconds
        4.0...10.0
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016, paused: !isAnimating)) { timeline in
            Canvas { context, size in
                // Draw each particle
                for particle in particles {
                    // Apply expansion scale if particle is expanding
                    let effectiveScale = particle.scale * particle.expansionScale
                    
                    let path = Path(ellipseIn: CGRect(
                        x: particle.position.x - effectiveScale/2,
                        y: particle.position.y - effectiveScale/2,
                        width: effectiveScale,
                        height: effectiveScale
                    ))
                    
                    // Calculate remaining life percentage
                    let elapsedTime = -particle.birthTime.timeIntervalSinceNow
                    let lifePercentage = min(1.0, max(0.0, elapsedTime / particle.lifespan))
                    
                    // Fade out as the particle ages
                    let fadeOpacity = particle.opacity * (1.0 - lifePercentage)
                    
                    context.opacity = fadeOpacity
                    context.fill(path, with: .color(particle.color))
                    
                    // Optional: Add a subtle glow effect for higher scores
                    if readinessScore > 70 {
                        context.opacity = fadeOpacity * 0.3
                        context.fill(path, with: .color(particle.color))
                        
                        // Larger glow for higher scores
                        let glowScale = effectiveScale * 1.8
                        let glowPath = Path(ellipseIn: CGRect(
                            x: particle.position.x - glowScale/2,
                            y: particle.position.y - glowScale/2,
                            width: glowScale,
                            height: glowScale
                        ))
                        context.opacity = fadeOpacity * 0.15
                        context.fill(glowPath, with: .color(particle.color))
                    }
                }
            }
            .onChange(of: timeline.date) { _, currentTime in
                // Calculate delta time for smooth animation
                let deltaTime = currentTime.timeIntervalSince(lastUpdateTime)
                lastUpdateTime = currentTime
                
                if isAnimating {
                    if particles.isEmpty || !isInitialized {
                        initializeParticles()
                        isInitialized = true
                    }
                    
                    // Update existing particles
                    updateParticles(deltaTime: deltaTime)
                    
                    // Regenerate particles that have expired
                    regenerateExpiredParticles()
                } else {
                    particles = []
                    isInitialized = false
                }
            }
        }
        .onChange(of: readinessScore) { _, _ in
            isInitialized = false
            particles = []
        }
        .onChange(of: isTapped) { _, newValue in
            if newValue {
                applyTapForce()
            }
        }
    }
    
    private func initializeParticles() {
        particles = []
        let center = CGPoint(x: 150, y: 150)
        
        for _ in 0..<particleCount {
            createParticle(center: center)
        }
    }
    
    private func createParticle(center: CGPoint) {
        // Random position around the center
        let angle = Double.random(in: 0..<2*Double.pi)
        let distance = Double.random(in: 20..<95)
        let position = CGPoint(
            x: center.x + cos(angle) * distance,
            y: center.y + sin(angle) * distance
        )
        
        // Velocity perpendicular to radius (for orbital motion)
        let speed = Double.random(in: 0.5..<1.5) * particleSpeed
        let velocity = CGPoint(
            x: -sin(angle) * speed,
            y: cos(angle) * speed
        )
        
        // Vary particle appearance based on score - larger particles overall
        let scale = readinessScore > 70 ? 
            CGFloat.random(in: 4.5..<8.0) : 
            CGFloat.random(in: 3.5..<6.0)
        
        let opacity = readinessScore > 50 ? 
            Double.random(in: 0.6..<1.0) : 
            Double.random(in: 0.3..<0.7)
        
        // Color variation
        let colorVariation = Double.random(in: -0.3..<0.3)
        let particleColor = categoryColor.opacity(1.0 + colorVariation)
        
        // Random lifespan
        let lifespan = Double.random(in: particleLifespan)
        
        // Random energy level for unpredictable behavior
        let energyLevel = Double.random(in: 0.5...1.5)
        
        particles.append(Particle(
            position: position,
            velocity: velocity,
            scale: scale,
            opacity: opacity,
            color: particleColor,
            lifespan: lifespan,
            birthTime: Date(),
            energyLevel: energyLevel
        ))
    }
    
    private func updateParticles(deltaTime: TimeInterval) {
        let center = CGPoint(x: 150, y: 150)
        let scaledDeltaTime = min(deltaTime, 0.1) // Cap delta time to prevent large jumps
        
        for i in 0..<particles.count {
            // Update position with delta time for smooth animation
            var particle = particles[i]
            particle.position.x += particle.velocity.x * scaledDeltaTime * 60 // Scale to ~60fps
            particle.position.y += particle.velocity.y * scaledDeltaTime * 60
            
            // Calculate vector from center to particle
            let dx = particle.position.x - center.x
            let dy = particle.position.y - center.y
            let distanceSquared = dx*dx + dy*dy
            let distance = sqrt(distanceSquared)
            
            // Gradually reduce expansion scale if particle is expanding
            if particle.isExpanding && particle.expansionScale > 1.0 {
                particle.expansionScale = max(1.0, particle.expansionScale - 0.05)
                
                // If expansion is complete, reset the flag
                if particle.expansionScale <= 1.0 {
                    particle.isExpanding = false
                }
            }
            
            // Dynamic scale based on distance from center (proximity effect)
            // Maximum distance is boundaryRadius (95 in normal state)
            let maxDistance = 95.0
            let minScaleFactor = 0.6 // Particles at the edge will be 60% of their base size
            let maxScaleFactor = 1.3 // Particles at the center will be 130% of their base size
            
            // Calculate scale factor based on distance (inverse relationship)
            // Closer to center = larger, further from center = smaller
            let distanceRatio = min(1.0, distance / maxDistance)
            let proximityScaleFactor = maxScaleFactor - (distanceRatio * (maxScaleFactor - minScaleFactor))
            
            // Apply the proximity scale factor (but not during expansion)
            if !particle.isExpanding {
                particle.expansionScale = proximityScaleFactor
            }
            
            // Orbital dynamics - higher scores have more stable orbits
            if distance > 0 {
                // If particle is in expansion mode, reduce gravitational pull
                let gravityMultiplier = particle.isExpanding ? 0.2 : 1.0
                
                // Gravitational attraction to center
                let gravityForce = gravitationalForce * particle.energyLevel * gravityMultiplier
                particle.velocity.x -= dx / distance * gravityForce
                particle.velocity.y -= dy / distance * gravityForce
                
                // Add randomness based on readiness score
                let randomFactor = (100 - readinessScore) / 500
                if Double.random(in: 0...1) < 0.1 { // Only apply occasionally for natural movement
                    let randomAngle = Double.random(in: 0..<2*Double.pi)
                    let randomForce = Double.random(in: 0...randomFactor) * particle.energyLevel
                    
                    particle.velocity.x += cos(randomAngle) * randomForce
                    particle.velocity.y += sin(randomAngle) * randomForce
                }
                
                // Add slight chaos for low scores
                if readinessScore < 60 {
                    let chaos = (60 - readinessScore) / 400 * particle.energyLevel
                    particle.velocity.x += Double.random(in: -chaos...chaos)
                    particle.velocity.y += Double.random(in: -chaos...chaos)
                }
                
                // Harmonize movement at high scores
                if readinessScore > 80 {
                    // Make high-scoring particles flow more in unison
                    let harmonyFactor = (readinessScore - 80) / 300
                    let targetAngle = Double.random(in: 0..<2*Double.pi)
                    particle.velocity.x += cos(targetAngle) * harmonyFactor
                    particle.velocity.y += sin(targetAngle) * harmonyFactor
                }
                
                // Occasional energy bursts for more unpredictable behavior
                if Double.random(in: 0...1) < 0.005 * particle.energyLevel {
                    let burstAngle = Double.random(in: 0..<2*Double.pi)
                    let burstStrength = Double.random(in: 0.5...1.5) * (1.0 - orbitStability)
                    
                    particle.velocity.x += cos(burstAngle) * burstStrength
                    particle.velocity.y += sin(burstAngle) * burstStrength
                }
            }
            
            // Extended boundary for particles in expansion mode
            let boundaryRadius = particle.isExpanding ? 300.0 : 95.0
            
            // Boundary collision (keep particles inside the circle or extended boundary)
            if distance > boundaryRadius {
                let bounceStrength = 0.3
                let nx = dx / distance
                let ny = dy / distance
                
                // Calculate reflection vector
                let dot = particle.velocity.x * nx + particle.velocity.y * ny
                
                particle.velocity.x -= 2 * dot * nx * bounceStrength
                particle.velocity.y -= 2 * dot * ny * bounceStrength
                
                // Move particle back inside boundary
                particle.position.x = center.x + nx * boundaryRadius
                particle.position.y = center.y + ny * boundaryRadius
                
                // If particle is in expansion mode and hits the extended boundary, start returning
                if particle.isExpanding {
                    particle.isExpanding = false
                }
            }
            
            // Apply velocity damping for stability
            let dampingFactor = 0.99 - ((100 - readinessScore) / 5000) // More damping for lower scores
            particle.velocity.x *= dampingFactor
            particle.velocity.y *= dampingFactor
            
            // Update particle in array
            particles[i] = particle
        }
    }
    
    private func regenerateExpiredParticles() {
        let center = CGPoint(x: 150, y: 150)
        let currentTime = Date()
        
        // Find and replace expired particles
        for i in 0..<particles.count {
            let particle = particles[i]
            let age = currentTime.timeIntervalSince(particle.birthTime)
            
            if age > particle.lifespan {
                // Replace with a new particle
                createParticle(center: center)
                particles.remove(at: i)
                break // Only replace one per frame to avoid stuttering
            }
        }
        
        // Ensure we maintain the desired particle count
        while particles.count < particleCount {
            createParticle(center: center)
        }
    }
    
    private func applyTapForce() {
        let center = CGPoint(x: 150, y: 150)
        let repulsionStrength = 6.0 * (1.0 + (100 - readinessScore) / 100) // Further increased strength
        
        // Apply an outward force to all particles
        for i in 0..<particles.count {
            var particle = particles[i]
            
            // Vector from center to particle
            let dx = particle.position.x - center.x
            let dy = particle.position.y - center.y
            let distance = sqrt(dx*dx + dy*dy)
            
            if distance > 0 {
                // Normalize and apply repulsion force
                let nx = dx / distance
                let ny = dy / distance
                
                // Force decreases with distance from center
                let forceFactor = max(0.3, 1.0 - (distance / 100)) * repulsionStrength
                
                // Apply force based on particle's energy level for varied response
                particle.velocity.x += nx * forceFactor * particle.energyLevel * 3.0 // Tripled for even more dramatic effect
                particle.velocity.y += ny * forceFactor * particle.energyLevel * 3.0
                
                // Add some randomness to the explosion
                let randomAngle = Double.random(in: 0..<2*Double.pi)
                let randomForce = Double.random(in: 0...1.5) * particle.energyLevel // Increased randomness
                
                particle.velocity.x += cos(randomAngle) * randomForce
                particle.velocity.y += sin(randomAngle) * randomForce
                
                // Set particle to expansion mode
                particle.isExpanding = true
                
                // Store the current proximity-based scale factor
                let currentScale = particle.expansionScale
                
                // Randomly increase particle size during expansion
                // The expansion scale is now a multiplier on top of the proximity scale
                let expansionMultiplier = CGFloat.random(in: 1.6...3.2)
                particle.expansionScale = currentScale * expansionMultiplier
                
                // Update particle
                particles[i] = particle
            }
        }
    }
}

struct TodaysScoreParticlesView_Previews: PreviewProvider {
    static var previews: some View {
        TodaysScoreParticlesView(viewModel: ReadinessViewModel())
    }
}
