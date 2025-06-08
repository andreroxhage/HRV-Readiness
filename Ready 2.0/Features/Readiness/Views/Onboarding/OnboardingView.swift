import SwiftUI
import Foundation
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: ReadinessViewModel
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var currentPage = 0
    @State private var showHealthRequiredAlert = false
    
    @State private var animateIcons = false
    @State private var animateContent = false
    @State private var showPulse = false
    @State private var pageTransition: AnyTransition = .opacity
    @State private var transitionDirection = 1 // 1 for forward, -1 for backward
    
    @State private var activeParticleColor: Color = .green // For score explanation particles
    @State private var currentScoreCategory = 0
    @State private var mockReadinessScore: Double = 90 // Mock score for the demo particles
    
    private let backgroundColor = Color(UIColor.systemBackground)
    private let secondaryBackgroundColor = Color(UIColor.secondarySystemBackground)
    

    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [backgroundColor, backgroundColor.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Content with transition
            ZStack {
                if currentPage == 0 {
                    welcomeView
                        .transition(pageTransition)
                } else if currentPage == 1 {
                    scoreExplanationView
                        .transition(pageTransition)
                } else if currentPage == 2 {
                    hrvExplanationView
                        .transition(pageTransition)
                } else if currentPage == 3 {
                    appBenefitsView
                        .transition(pageTransition)
                } else if currentPage == 4 {
                    factorsView
                        .transition(pageTransition)
                } else if currentPage == 5 {
                    healthPermissionsView
                        .transition(pageTransition)
                } else if currentPage == 6 {
                    dataImportView
                        .transition(pageTransition)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: currentPage)
            
            // Navigation dots
            VStack {
                Spacer()
                // Hide on first and last page
                if currentPage != 0 && currentPage != 6 {
                    pageIndicator
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard)
            .animation(.easeInOut(duration: 0.4), value: currentPage)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    animateIcons = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animateContent = true
                }
            }
            
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                showPulse = true
            }
        }


    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 24) {
            if currentPage > 0 {
                Button {
                    transitionDirection = -1
                    pageTransition = .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentPage -= 1
                        resetAndAnimateNewContent()
                    }
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 8) {
                ForEach(0..<7) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.4))
                        .frame(width: currentPage == index ? 10 : 8, height: currentPage == index ? 10 : 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            
            if currentPage < 6 {
                Button {
                    transitionDirection = 1
                    pageTransition = .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentPage += 1
                        resetAndAnimateNewContent()
                    }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.8))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    private func resetAndAnimateNewContent() {
        // First reset animations
        withAnimation(.easeOut(duration: 0.1)) {
            animateIcons = false
            animateContent = false
        }
        
        // Then animate new content after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                animateIcons = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.6)) {
                animateContent = true
            }
        }
    }
    
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                MockParticlesView(
                    readinessScore: 90,
                    categoryColor: .green,
                    showScore: false
                )
                .frame(width: 240, height: 240)
            }
            
            VStack(spacing: 16) {
                Text("Welcome to Ready")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                Text("Your personal readiness tracker powered by heart rate variability")
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 16)
            }
            
            Spacer()
            
            Button {
                transitionDirection = 1
                pageTransition = .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentPage = 1
                    resetAndAnimateNewContent()
                }
            } label: {
                HStack {
                    Text("Get Started")
                        .fontWeight(.semibold)
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundColor(.white)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color.accentColor)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .opacity(animateContent ? 1 : 0)
            .scaleEffect(animateContent ? 1 : 0.9)
            
            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 16)
    }
    
    private var scoreExplanationView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Readiness")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 32)
                    
                    // Use TodaysScoreParticlesView instead of custom implementation
                    MockParticlesView(
                        readinessScore: mockReadinessScore,
                        categoryColor: categoryColor
                    )
                    .frame(height: 250)
                    .opacity(animateContent ? 1 : 0)
                    .onAppear {
                        showPulse = true
                        startScoreCategoryRotation()
                    }
                    .onDisappear {
                        // Stop any pending changes when leaving this view
                        mockReadinessScore = 90 
                        activeParticleColor = .green
                    }
                    
                    VStack(spacing: 16) {
                        // Score categories
                        scoreCategoryCard(
                            title: "Optimal (80-100)",
                            description: "Your body is well-recovered and ready for high-intensity training.",
                            color: ReadinessCategory.optimal.color,
                            isActive: mockReadinessScore >= 80
                        )
                        
                        scoreCategoryCard(
                            title: "Moderate (50-79)",
                            description: "Your body is moderately recovered. Consider moderate-intensity activity.",
                            color: ReadinessCategory.moderate.color,
                            isActive: mockReadinessScore >= 50 && mockReadinessScore < 80
                        )
                        
                        scoreCategoryCard(
                            title: "Low (30-49)",
                            description: "Your body shows signs of fatigue. Consider light activity or active recovery.",
                            color: ReadinessCategory.low.color,
                            isActive: mockReadinessScore >= 30 && mockReadinessScore < 50
                        )
                        
                        scoreCategoryCard(
                            title: "Fatigue (0-29)",
                            description: "Your body needs rest. Focus on recovery and avoid intense training.",
                            color: ReadinessCategory.fatigue.color,
                            isActive: mockReadinessScore < 30
                        )
                    }
                    .padding(.horizontal, 16)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    
                    // Add padding at bottom for scrolling
                    Spacer().frame(height: 60) // Extra padding to account for the page indicator
                }
            }
        }
    }
    
    private func scoreCategoryCard(title: String, description: String, color: Color, isActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 4, height: .infinity)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isActive ? .bold : .semibold)
                    .foregroundColor(color)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.1) : Color.clear)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
    
    private func startScoreCategoryRotation() {
        // Reset to first category (Optimal)
        currentScoreCategory = 0
        updateCategoryScore()
        
        // Schedule category changes if we're still on this page
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if currentPage == 1 {
                currentScoreCategory = 1 // Moderate
                updateCategoryScore()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if currentPage == 1 {
                        currentScoreCategory = 2 // Low
                        updateCategoryScore()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            if currentPage == 1 {
                                currentScoreCategory = 3 // Fatigue
                                updateCategoryScore()
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    if currentPage == 1 {
                                        // Restart the cycle
                                        startScoreCategoryRotation()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updateCategoryScore() {
        withAnimation(.easeInOut(duration: 1.0)) {
            switch currentScoreCategory {
            case 0: // Optimal
                mockReadinessScore = 90
                activeParticleColor = ReadinessCategory.optimal.color
            case 1: // Moderate
                mockReadinessScore = 65
                activeParticleColor = ReadinessCategory.moderate.color
            case 2: // Low
                mockReadinessScore = 40
                activeParticleColor = ReadinessCategory.low.color
            case 3: // Fatigue
                mockReadinessScore = 20
                activeParticleColor = ReadinessCategory.fatigue.color
            default:
                mockReadinessScore = 90
                activeParticleColor = ReadinessCategory.optimal.color
            }
        }
    }
    
    private var hrvExplanationView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Understanding HRV")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                    
                    GeometryReader { geometry in
                        let isLandscape = geometry.size.width > geometry.size.height
                        
                        if isLandscape {
                            // Landscape layout - 2 columns
                            HStack(alignment: .top, spacing: 15) {
                                VStack(spacing: 15) {
                                    explanationCard(
                                        icon: "waveform.path.ecg",
                                        title: "Heart Rate Variability",
                                        description: "HRV measures the variation in time between consecutive heartbeats. It's a key indicator of your autonomic nervous system function."
                                    )
                                    
                                    explanationCard(
                                        icon: "arrow.up.heart",
                                        title: "Higher HRV",
                                        description: "Generally indicates better recovery, stress resilience, and readiness to perform."
                                    )
                                }
                                
                                VStack(spacing: 15) {
                                    explanationCard(
                                        icon: "arrow.down.heart",
                                        title: "Lower HRV",
                                        description: "May signal fatigue, stress, or inadequate recovery, suggesting you might need more rest."
                                    )
                                    
                                    explanationCard(
                                        icon: "gauge.medium",
                                        title: "Readiness Score",
                                        description: "We convert your HRV data into an easy-to-understand readiness score from 0-100."
                                    )
                                }
                            }
                        } else {
                            // Portrait layout - stacked
                            VStack(spacing: 15) {
                                explanationCard(
                                    icon: "waveform.path.ecg",
                                    title: "Heart Rate Variability",
                                    description: "HRV measures the variation in time between consecutive heartbeats. It's a key indicator of your autonomic nervous system function."
                                )
                                
                                explanationCard(
                                    icon: "arrow.up.heart",
                                    title: "Higher HRV",
                                    description: "Generally indicates better recovery, stress resilience, and readiness to perform."
                                )
                                
                                explanationCard(
                                    icon: "arrow.down.heart",
                                    title: "Lower HRV",
                                    description: "May signal fatigue, stress, or inadequate recovery, suggesting you might need more rest."
                                )
                                
                                explanationCard(
                                    icon: "gauge.medium",
                                    title: "Readiness Score",
                                    description: "We convert your HRV data into an easy-to-understand readiness score from 0-100."
                                )
                            }
                        }
                    }
                    .frame(minHeight: 450)
                    
                    // Add padding at bottom for scrolling
                    Spacer().frame(height: 60) // Extra padding to account for the page indicator
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 30)
            }
        }
    }
    
    private var appBenefitsView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Why Track Readiness?")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                    
                    GeometryReader { geometry in
                        let isLandscape = geometry.size.width > geometry.size.height
                        
                        if isLandscape {
                            // Landscape layout
                            HStack(alignment: .top, spacing: 15) {
                                VStack(spacing: 15) {
                                    benefitCard(
                                        icon: "chart.line.uptrend.xyaxis",
                                        title: "Optimize Performance",
                                        description: "Understand when your body is ready for intense activity and when it needs recovery.",
                                        color: .orange
                                    )
                                }
                                
                                VStack(spacing: 15) {
                                    benefitCard(
                                        icon: "shield.checkerboard",
                                        title: "Prevent Overtraining",
                                        description: "Identify early warning signs of fatigue to reduce injury risk and burnout.",
                                        color: .orange
                                    )
                                }
                                
                                VStack(spacing: 15) {
                                    benefitCard(
                                        icon: "person.fill.checkmark",
                                        title: "Personalized Insights",
                                        description: "Get data-driven recommendations based on your unique physiology.",
                                        color: .orange
                                    )
                                }
                            }
                        } else {
                            // Portrait layout
                            VStack(spacing: 15) {
                                benefitCard(
                                    icon: "chart.line.uptrend.xyaxis",
                                    title: "Optimize Performance",
                                    description: "Understand when your body is ready for intense activity and when it needs recovery.",
                                    color: .orange
                                )
                                
                                benefitCard(
                                    icon: "shield.checkerboard",
                                    title: "Prevent Overtraining",
                                    description: "Identify early warning signs of fatigue to reduce injury risk and burnout.",
                                    color: .orange
                                )
                                
                                benefitCard(
                                    icon: "person.fill.checkmark",
                                    title: "Personalized Insights",
                                    description: "Get data-driven recommendations based on your unique physiology.",
                                    color: .orange
                                )
                            }
                        }
                    }
                    .frame(minHeight: 450)
                    
                    // Add padding at bottom for scrolling
                    Spacer().frame(height: 60) // Extra padding to account for the page indicator
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 30)
            }
        }
    }
    
    private var factorsView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Factors That Affect Readiness")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)
                    
                    GeometryReader { geometry in
                        let isLandscape = geometry.size.width > geometry.size.height
                        
                        if isLandscape {
                            // Landscape layout - multiple columns
                            HStack(alignment: .top, spacing: 15) {
                                VStack(spacing: 15) {
                                    factorCard(
                                        icon: "powersleep",
                                        title: "Sleep Quality",
                                        description: "Poor or insufficient sleep can lower HRV and reduce readiness.",
                                        color: .yellow
                                    )
                                    
                                    factorCard(
                                        icon: "brain.head.profile",
                                        title: "Mental Stress",
                                        description: "Psychological stress can significantly impact HRV measurements.",
                                        color: .yellow
                                    )
                                }
                                
                                VStack(spacing: 15) {
                                    factorCard(
                                        icon: "figure.run",
                                        title: "Physical Activity",
                                        description: "Exercise impacts recovery needs - balance training with rest.",
                                        color: .yellow
                                    )
                                    
                                    factorCard(
                                        icon: "wineglass",
                                        title: "Alcohol & Nutrition",
                                        description: "What you consume affects your body's recovery state.",
                                        color: .yellow
                                    )
                                }
                                
                                VStack(spacing: 15) {
                                    factorCard(
                                        icon: "thermometer.medium",
                                        title: "Illness & Inflammation",
                                        description: "Being sick taxes your body and lowers recovery capacity.",
                                        color: .yellow
                                    )
                                }
                            }
                        } else {
                            // Portrait layout - stacked
                            VStack(spacing: 15) {
                                factorCard(
                                    icon: "powersleep",
                                    title: "Sleep Quality",
                                    description: "Poor or insufficient sleep can lower HRV and reduce readiness.",
                                    color: .yellow
                                )
                                
                                factorCard(
                                    icon: "brain.head.profile",
                                    title: "Mental Stress",
                                    description: "Psychological stress can significantly impact HRV measurements.",
                                    color: .yellow
                                )
                                
                                factorCard(
                                    icon: "figure.run",
                                    title: "Physical Activity",
                                    description: "Exercise impacts recovery needs - balance training with rest.",
                                    color: .yellow
                                )
                                
                                factorCard(
                                    icon: "wineglass",
                                    title: "Alcohol & Nutrition",
                                    description: "What you consume affects your body's recovery state.",
                                    color: .yellow
                                )
                                
                                factorCard(
                                    icon: "thermometer.medium",
                                    title: "Illness & Inflammation",
                                    description: "Being sick taxes your body and lowers recovery capacity.",
                                    color: .yellow
                                )
                            }
                            .opacity(animateContent ? 1 : 0)
                            .offset(x: animateContent ? 0 : 50)
                        }
                    }
                    .frame(minHeight: 450)
                    
                    // Add padding at bottom for scrolling
                    Spacer().frame(height: 60) // Extra padding to account for the page indicator
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 30)
            }
        }
    }
    
    private var healthPermissionsView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ScrollView {
              VStack(alignment: .center, spacing: isLandscape ? 12 : 32) {
                    if !isLandscape {
                        Spacer(minLength: 20)
                    }
                    
                    ZStack {
                        Image(systemName: "heart.text.square.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: isLandscape ? 70 : 90, height: isLandscape ? 70 : 90)
                            .foregroundColor(.red)
                            .scaleEffect(animateIcons ? 1 : 0.7)
                    }
                    
                    VStack(spacing: 10) {
                        Text("Health Data Access")
                            .font(.system(size: isLandscape ? 26 : 32, weight: .bold, design: .rounded))
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        healthDataItem(icon: "waveform.path.ecg", text: "Heart Rate Variability", color: .red)
                        healthDataItem(icon: "heart.fill", text: "Resting Heart Rate", color: .red)
                        healthDataItem(icon: "bed.double.fill", text: "Sleep Analysis", color: .blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .opacity(animateContent ? 1 : 0)
                    
                    Text("This access is required to use Ready. \n \n The app cannot function without these permissions.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateContent ? 1 : 0)
                    
                    if !isLandscape {
                        Spacer()
                    }
                    
                    Text("Requesting access to your health data...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateContent ? 1 : 0)
                    
                    Spacer().frame(height: isLandscape ? 20 : 30)
                }
                .padding()
            }
        }
        .onAppear {
            // Automatically request HealthKit authorization when this page appears
            requestHealthKitAuthorization()
        }
    }
    
    private var dataImportView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ScrollView {
                VStack(spacing: isLandscape ? 15 : 30) {
                    if !isLandscape {
                        Spacer(minLength: 20)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: isLandscape ? 100 : 120, height: isLandscape ? 100 : 120)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: isLandscape ? 65 : 80, height: isLandscape ? 65 : 80)
                            .foregroundColor(.green)
                    }
                    
                    Text("Ready to Go!")
                        .font(.system(size: isLandscape ? 28 : 32, weight: .bold, design: .rounded))
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    
                    VStack {
                        Text("Your health data access has been configured. Ready is now set up and ready to help you track your recovery and readiness.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .opacity(animateContent ? 1 : 0)
                    }
                    .frame(height: 60)
                    .padding(.bottom, 8)
                    
                    if !isLandscape {
                        Spacer()
                    }
                    
                    VStack {
                        Spacer(minLength: 60)
                        
                        Button {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                hasCompletedOnboarding = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                Text("Start Using Ready")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .opacity(animateContent ? 1 : 0)
                        .scaleEffect(animateContent ? 1 : 0.9)
                    }
                    .padding(.bottom, 40)
                    
                    Spacer().frame(height: isLandscape ? 30 : 60)
                }
                .padding()
            }
        }
    }
    
    private func explanationCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(Color.accentColor)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
                .opacity(animateIcons ? 1 : 0)
                .scaleEffect(animateIcons ? 1 : 0.5)
                .rotationEffect(.degrees(animateIcons ? 0 : -180))
                .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateIcons)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(secondaryBackgroundColor)
                .opacity(animateContent ? 1 : 0)
                .scaleEffect(animateContent ? 1 : 0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
                .opacity(animateContent ? 1 : 0)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
    }
    
    private func benefitCard(icon: String, title: String, description: String, color: Color = Color.accentColor) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())
                .opacity(animateIcons ? 1 : 0)
                .scaleEffect(animateIcons ? 1 : 0.5)
                .rotationEffect(.degrees(animateIcons ? 0 : -180))
                .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateIcons)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(secondaryBackgroundColor)
                .opacity(animateContent ? 1 : 0)
                .scaleEffect(animateContent ? 1 : 0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: 1)
                .opacity(animateContent ? 1 : 0)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
    }
    
    private func factorCard(icon: String, title: String, description: String, color: Color = Color.accentColor) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())
                .opacity(animateIcons ? 1 : 0)
                .scaleEffect(animateIcons ? 1 : 0.5)
                .rotationEffect(.degrees(animateIcons ? 0 : -180))
                .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateIcons)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(secondaryBackgroundColor)
                .opacity(animateContent ? 1 : 0)
                .scaleEffect(animateContent ? 1 : 0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.1), lineWidth: 1)
                .opacity(animateContent ? 1 : 0)
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
    }
    
    private func healthDataItem(icon: String, text: String, color: Color = .red) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 28)
                .opacity(animateIcons ? 1 : 0)
                .scaleEffect(animateIcons ? 1 : 0.5)
                .rotationEffect(.degrees(animateIcons ? 0 : -180))
                .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateIcons)
                        
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3), value: animateContent)
        }
        .frame(maxWidth: 280)
    }
    
    private func requestHealthKitAuthorization() {
        // Actually request the permission but don't wait for result
        Task {
            do {
                let healthKitManager = HealthKitManager.shared
                try await healthKitManager.requestAuthorization()
            } catch {
                // Silently handle any errors - we're not checking the result anyway
            }
        }
        
        // Immediately move to next page regardless of permission result
        transitionDirection = 1
        pageTransition = .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentPage += 1
            resetAndAnimateNewContent()
        }
    }
    
    // Get the category color based on the mockReadinessScore
    private var categoryColor: Color {
        if mockReadinessScore >= 80 {
            return .green
        } else if mockReadinessScore >= 50 {
            return .yellow
        } else if mockReadinessScore >= 30 {
            return .orange
        } else {
            return .red
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(viewModel: ReadinessViewModel())
    }
}

// Create a simpler version of the particles view for onboarding
struct MockParticlesView: View {
    let readinessScore: Double
    let categoryColor: Color
    @State private var isAnimating = false
    @State private var displayScore: Double
    @State private var shouldExplode = false
    let showScore: Bool
    
    init(readinessScore: Double, categoryColor: Color, showScore: Bool = true) {
        self.readinessScore = readinessScore
        self.categoryColor = categoryColor
        self.showScore = showScore
        self.displayScore = readinessScore
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.05))
                .frame(width: 200, height: 200)
            
            // Main particle effect
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [categoryColor.opacity(0.7), categoryColor.opacity(0.3)]),
                        center: .center,
                        startRadius: 5,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            // Add a subtle glow effect
            Circle()
                .fill(categoryColor.opacity(0.15))
                .frame(width: 240, height: 240)
                .blur(radius: 15)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Regular floating particles
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(categoryColor)
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                    .offset(
                        x: CGFloat.random(in: -70...70), 
                        y: CGFloat.random(in: -70...70)
                    )
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 1.5...3.0))
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            
            // Explosion effect particles that appear during transitions
            if shouldExplode {
                ForEach(0..<20, id: \.self) { i in
                    let size = CGFloat.random(in: 3...8)
                    let angle = Double.random(in: 0..<2*Double.pi)
                    let distance = Double.random(in: 30...120)
                    
                    Circle()
                        .fill(categoryColor)
                        .frame(width: size, height: size)
                        .offset(
                            x: cos(angle) * distance,
                            y: sin(angle) * distance
                        )
                        .opacity(shouldExplode ? 0 : 1) // Fade out
                        .animation(
                            Animation.easeOut(duration: Double.random(in: 0.8...1.2)),
                            value: shouldExplode
                        )
                }
            }
            
            // Add a readiness score label in the center with animated transitions
            if showScore {
                AnimatedNumber(value: $displayScore)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .scaleEffect(shouldExplode ? 1.2 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shouldExplode)
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onChange(of: readinessScore) { oldValue, newValue in
            // First trigger the explosion effect
            shouldExplode = true
            
            // Then start animating to the new value
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                displayScore = newValue
            }
            
            // Reset explosion after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                shouldExplode = false
            }
            
            // Reset animation on score change
            isAnimating = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = true
            }
        }
    }
}

// Animated number view for smooth transitions between numbers
struct AnimatedNumber: View {
    @Binding var value: Double
    
    var body: some View {
        Text("\(Int(value))")
            .contentTransition(.numericText())
    }
}

// Animated percentage view for smooth transitions between percentage values
struct AnimatedPercentage: View {
    let value: Double
    @State private var displayValue: Double
    
    init(value: Double) {
        self.value = value
        self._displayValue = State(initialValue: value)
    }
    
    var body: some View {
        Text("\(Int(displayValue * 100))%")
            .contentTransition(.numericText())
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
            .onAppear {
                displayValue = value
            }
    }
}
