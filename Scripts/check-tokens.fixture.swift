// check-tokens.fixture.swift — every rule in check-tokens.sh, planted once or more.
//
// Not compiled: it lives in Scripts/, outside the app's synchronised folders. Each line
// marked `expect:` must be reported; `check-tokens.sh --self-test` counts them and checks
// that every rule fired at least once. The unmarked lines must not be reported.

struct Fixture: View {
  var body: some View {
    VStack(spacing: 8) { // expect: spacing-literal
      Text("a").padding(12) // expect: spacing-literal
      Text("b").padding(.horizontal, 4) // expect: spacing-literal
      Text("c").frame(width: 20, height: 20) // expect: frame-literal
      Text("d").frame(minWidth: 200) // expect: frame-literal
      Text("e").frame(maxHeight: 40.5) // expect: frame-literal
      RoundedRectangle(cornerRadius: 8) // expect: radius-literal
      Text("f").clipShape(.rect(cornerRadius: 6)) // expect: radius-literal
      Circle().stroke(.red, lineWidth: 1) // expect: border-literal
      Text("g").border(.gray, width: 0.5) // expect: border-literal
      Text("h").font(.system(size: 14)) // expect: font-size-literal
      Text("i").foregroundStyle(Color(red: 0.2, green: 0.3, blue: 0.4)) // expect: colour-literal
      Text("j").foregroundStyle(Color(white: 0.5)) // expect: colour-literal
      Text("k").foregroundStyle(Color(.sRGB, red: 1, green: 0, blue: 0)) // expect: colour-literal
      Text("l").foregroundStyle(Color("Accent")) // expect: colour-literal
      Text("m").foregroundStyle(Color(NSColor.red)) // expect: colour-literal
      let hex = 0x1A1A1F // expect: colour-literal
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 4)]) {} // expect: spacing-literal

      // Clean: tokens, and the one sanctioned computed view.
      Text("n").padding(.spacing.medium)
      Text("o").frame(width: .iconSize.small, height: .iconSize.small)
      RoundedRectangle(cornerRadius: .cornerRadius.large)
      Circle().stroke(.accent, lineWidth: .borderWidth.hairline)
      HStack(spacing: .spacing.small) {}
      Text("p").font(.body).foregroundStyle(.textPrimary)
      // A comment that says padding(8) and Color(red: 1, …) is prose.
      Text("q").frame(width: 400, height: 300) // tokens: allow — preview canvas size
    }
  }

  var header: some View { Text("r") } // expect: computed-view
  private var footer: some View { Text("s") } // expect: computed-view
}
