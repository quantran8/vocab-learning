import SwiftUI

/// Pick the wrong grapheme, then type its replacement; leaving it empty deletes the grapheme.
struct SurgeryTaskView: View {
    let attempt: TaskAttempt
    @Environment(PracticeSessionStore.self) private var store
    @Environment(\.motion) private var motion
    @State private var selectedIndex: Int?
    @State private var replacement = ""
    @State private var frames: [Int: CGRect] = [:]
    @State private var flyers: [Flyer] = []
    /// While the old box is thrown away, its slot holds a grey placeholder that the new letter lands in.
    @State private var swappedIndex: Int?
    @State private var landed = ""
    @State private var isSwapping = false

    var body: some View {
        TaskScaffold(attempt: attempt) {
            if case .surgery(let word, _, _) = attempt.task.body {
                let letters = PracticeAnswer.graphemes(word)
                VStack(spacing: Spacing.l) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                            letterBox(letter, index: index, total: letters.count)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    if selectedIndex != nil, !attempt.isFinished {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Eyebrow(text: "Replace with")
                            TextField("Leave empty to delete", text: $replacement)
                                .font(Typography.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, Spacing.m)
                                .frame(minHeight: Spacing.tileMinHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radii.tile, style: .continuous)
                                        .strokeBorder(Color.stroke, lineWidth: 1.5)
                                )
                                .trackFrame(Self.fieldKey)
                        }
                    }
                }
                .coordinateSpace(name: Self.space)
                .onPreferenceChange(FramePreference.self) { frames = $0 }
                .overlay(alignment: .topLeading) {
                    ForEach(flyers) { FlyingPiece(flyer: $0) }
                        .allowsHitTesting(false)
                }
            }
        } action: {
            TaskActionBar(
                attempt: attempt,
                checkTitle: "Check fix",
                canCheck: selectedIndex != nil && !isSwapping,
                onCheck: commitRepair
            )
        }
        .onChange(of: attempt.status) { _, status in
            guard status == .answering else { return }
            selectedIndex = nil
            replacement = ""
            resetSwap()
        }
        .onChange(of: selectedIndex) { _, _ in
            replacement = ""
        }
    }

    /// The old box is thrown off screen, then the typed letter flies from the field into the grey slot it leaves.
    private func commitRepair() {
        guard let index = selectedIndex, !isSwapping else { return }
        let text = replacement
        guard !motion.reduceMotion, let box = frames[index] else {
            swappedIndex = index
            landed = text
            store.submitRepair(graphemeIndex: index, replacement: text)
            return
        }
        isSwapping = true
        swappedIndex = index
        let center = CGPoint(x: box.midX, y: box.midY)
        // Lobbed up in a parabola: the apex sits well above the box, then it drops away off one side.
        let side: CGFloat = Bool.random() ? 1 : -1
        let lift = CGFloat.random(in: 420...560)
        flyers.append(Flyer(
            letter: originalLetter(at: index) ?? "",
            from: center,
            control: CGPoint(x: center.x + side * 260, y: center.y - lift * 2),
            to: CGPoint(x: center.x + side * 640, y: center.y + 80),
            size: box.size,
            spin: Double(side) * Double.random(in: 120...240),
            isBox: true
        ))

        // Checking waits for the last piece to settle, so the result never interrupts the flight.
        var checkDelay = Self.boxFlightDuration
        if !text.isEmpty, let field = frames[Self.fieldKey] {
            checkDelay = Self.letterLandedDelay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                flyers.append(Flyer(
                    letter: PracticeAnswer.graphemes(text).last ?? text,
                    from: CGPoint(x: field.maxX - Spacing.l, y: field.midY),
                    control: CGPoint(x: (field.maxX - Spacing.l + center.x) / 2, y: (field.midY + center.y) / 2),
                    to: center,
                    size: box.size,
                    spin: 0,
                    isBox: false
                ))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { landed = text }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + checkDelay) {
            flyers = []
            isSwapping = false
            store.submitRepair(graphemeIndex: index, replacement: text)
        }
    }

    private func resetSwap() {
        swappedIndex = nil
        landed = ""
        flyers = []
        isSwapping = false
    }

    private func originalLetter(at index: Int) -> String? {
        guard case .surgery(let word, _, _) = attempt.task.body else { return nil }
        let letters = PracticeAnswer.graphemes(word)
        return letters.indices.contains(index) ? letters[index] : nil
    }

    private static let space = "surgery"
    private static let fieldKey = -1
    private static let boxFlightDuration: Double = 0.7
    /// The letter leaves at 0.2s and its spring settles by about 0.8s; the rest is a beat to read it in place.
    private static let letterLandedDelay: Double = 1.2

    private func letterBox(_ letter: String, index: Int, total: Int) -> some View {
        let isSwapped = swappedIndex == index
        let isSelected = selectedIndex == index && !isSwapped
        // Until the new letter lands, the slot is a grey stand-in like the reorder drop preview.
        let isPlaceholder = isSwapped && landed.isEmpty
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        return Button {
            selectedIndex = isSelected ? nil : index
            store.haptics.selectionChanged()
        } label: {
            Text(verbatim: isSwapped ? landed : letter)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .foregroundStyle(isSelected ? Color.selectedInk : Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 2)
                .frame(minWidth: 0, maxWidth: 52, minHeight: 52)
                .background(isPlaceholder ? Color.clear : (isSelected ? Color.selectedSurface : Color.surface), in: shape)
                .overlay {
                    if !isPlaceholder {
                        shape.strokeBorder(isSelected ? Color.interactive : Color.stroke, lineWidth: isSelected ? 2 : 1.5)
                    }
                }
                .background(shape.fill(isSelected ? Color.selectedDepth : Color.tileDepth).offset(y: isPlaceholder ? 0 : Spacing.tileDepth))
                .padding(.bottom, Spacing.tileDepth)
        }
        .buttonStyle(.plain)
        .trackFrame(index)
        .disabled(attempt.isFinished || isSwapping)
        .accessibilityLabel(Text("Letter \(index + 1) of \(total), \(letter)"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct Flyer: Identifiable {
    let id = UUID()
    let letter: String
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint
    let size: CGSize
    let spin: Double
    /// True for the discarded box (flies off screen); false for the typed letter flying into the slot.
    let isBox: Bool
}

private struct FlyingPiece: View {
    let flyer: Flyer
    @State private var arrived = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radii.chip, style: .continuous)
        let face = CGSize(width: flyer.size.width, height: flyer.size.height - Spacing.tileDepth)
        Text(verbatim: flyer.letter)
            .font(.system(.title2, design: .monospaced, weight: .bold))
            .foregroundStyle(flyer.isBox ? Color.selectedInk : Color.ink)
            .frame(width: face.width, height: face.height)
            .background(flyer.isBox ? Color.selectedSurface : Color.surface, in: shape)
            .overlay(shape.strokeBorder(flyer.isBox ? Color.interactive : Color.stroke, lineWidth: flyer.isBox ? 2 : 1.5))
            .background(shape.fill(flyer.isBox ? Color.selectedDepth : Color.tileDepth).offset(y: Spacing.tileDepth))
            .scaleEffect(arrived ? (flyer.isBox ? 1.4 : 1) : 1.3)
            .rotationEffect(.degrees(arrived ? flyer.spin : 0))
            .opacity(arrived && flyer.isBox ? 0 : 1)
            .position(flyer.from)
            .modifier(ArcEffect(progress: arrived ? 1 : 0, from: flyer.from, control: flyer.control, to: flyer.to))
            .onAppear {
                withAnimation(flyer.isBox ? .easeIn(duration: 0.65) : MotionTokens.snap) { arrived = true }
            }
    }
}

/// Moves a view along a quadratic Bézier from `from` to `to`; `progress` is animatable.
private struct ArcEffect: GeometryEffect {
    var progress: CGFloat
    let from: CGPoint
    let control: CGPoint
    let to: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = progress, u = 1 - t
        let x = u * u * from.x + 2 * u * t * control.x + t * t * to.x
        let y = u * u * from.y + 2 * u * t * control.y + t * t * to.y
        return ProjectionTransform(CGAffineTransform(translationX: x - from.x, y: y - from.y))
    }
}

private struct FramePreference: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private extension View {
    func trackFrame(_ key: Int) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: FramePreference.self, value: [key: proxy.frame(in: .named("surgery"))])
            }
        )
    }
}
