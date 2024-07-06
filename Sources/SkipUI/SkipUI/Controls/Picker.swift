// Copyright 2023 Skip
//
// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

#if SKIP
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.material.ContentAlpha
import androidx.compose.material3.DropdownMenu
import androidx.compose.runtime.Composable
import androidx.compose.runtime.MutableState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
#endif

public struct Picker<SelectionValue> : View, ListItemAdapting {
    let selection: Binding<SelectionValue>
    let label: ComposeBuilder
    let content: ComposeBuilder

    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> any View, @ViewBuilder label: () -> any View) {
        self.selection = selection
        self.content = ComposeBuilder.from(content)
        self.label = ComposeBuilder.from(label)
    }

    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> any View) {
        self.init(selection: selection, content: content, label: { Text(titleKey) })
    }

    public init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> any View) {
        self.init(selection: selection, content: content, label: { Text(verbatim: title) })
    }

    #if SKIP
    @Composable override func ComposeContent(context: ComposeContext) {
        let views = taggedViews(context: context)
        let style = EnvironmentValues.shared._pickerStyle ?? PickerStyle.automatic
        if EnvironmentValues.shared._labelsHidden || style != .navigationLink {
            // Most picker styles do not display their label outside of a Form (see ComposeListItem)
            ComposeSelectedValue(views: views, context: context, style: style)
        } else {
            // Navigation link style outside of a List. This style does display its label
            let contentContext = context.content()
            let navigator = LocalNavigator.current
            let title = titleFromLabel(context: contentContext)
            let modifier = context.modifier.clickable(onClick: {
                navigator?.navigateToView(PickerSelectionView(views: views, selection: selection, title: title))
            }, enabled: EnvironmentValues.shared.isEnabled)
            ComposeContainer(modifier: modifier, fillWidth: true) { modifier in
                Row(modifier: modifier, verticalAlignment: androidx.compose.ui.Alignment.CenterVertically) {
                    ComposeTextButton(label: label, context: contentContext)
                    androidx.compose.foundation.layout.Spacer(modifier: Modifier.width(8.dp))
                    androidx.compose.foundation.layout.Spacer(modifier: Modifier.weight(Float(1.0)))
                    ComposeSelectedValue(views: views, context: contentContext, style: style, performsAction: false)
                }
            }
        }
    }

    @Composable private func ComposeSelectedValue(views: [TagModifierView], context: ComposeContext, style: PickerStyle, performsAction: Bool = true) {
        let selectedValueView = views.first { $0.value == selection.wrappedValue } ?? EmptyView()
        let selectedValueLabel: View
        let isMenu: Bool
        switch style {
        case .automatic, .menu:
            selectedValueLabel = HStack(spacing: 2.0) {
                selectedValueView
                Image(systemName: "chevron.down").accessibilityHidden(true)
            }
            isMenu = true
            
        case .segmented:
            selectedValueLabel = HStack(spacing: 2.0) {
                ForEach(views) { view in
                    Button(action: { selection.wrappedValue = view.value as! SelectionValue }) {
                        view
                    }.buttonStyle(SegmentedButtonStyle(isSelected: view.value == selection.wrappedValue))
                }
            }
            isMenu = false

        default:
            selectedValueLabel = selectedValueView
            isMenu = false
        }
        
        if performsAction {
            let isMenuExpanded = remember { mutableStateOf(false) }
            Box {
                ComposeTextButton(label: selectedValueLabel, context: context) { isMenuExpanded.value = !isMenuExpanded.value }
                if isMenu {
                    ComposePickerSelectionMenu(views: views, isExpanded: isMenuExpanded, context: context.content())
                }
            }
        } else {
            var foregroundStyle = EnvironmentValues.shared._tint ?? Color(colorImpl: { androidx.compose.ui.graphics.Color.Gray })
            if !EnvironmentValues.shared.isEnabled {
                foregroundStyle = foregroundStyle.opacity(Double(ContentAlpha.disabled))
            }
            selectedValueLabel.foregroundStyle(foregroundStyle).Compose(context: context)
        }
    }

    @Composable func shouldComposeListItem() -> Bool {
        return true
    }

    @Composable func ComposeListItem(context: ComposeContext, contentModifier: Modifier) {
        let views = taggedViews(context: context)
        let style = EnvironmentValues.shared._pickerStyle ?? PickerStyle.automatic
        var isMenu = false
        let isMenuExpanded = remember { mutableStateOf(false) }
        let onClick: () -> Void
        if style == .navigationLink {
            let navigator = LocalNavigator.current
            let title = titleFromLabel(context: context)
            onClick = { navigator?.navigateToView(PickerSelectionView(views: views, selection: selection, title: title)) }
        } else {
            isMenu = true
            onClick = { isMenuExpanded.value = !isMenuExpanded.value }
        }
        let modifier = Modifier.clickable(onClick: onClick, enabled: EnvironmentValues.shared.isEnabled).then(contentModifier)
        Row(modifier: modifier, verticalAlignment: androidx.compose.ui.Alignment.CenterVertically) {
            if !EnvironmentValues.shared._labelsHidden {
                label.Compose(context: context)
                androidx.compose.foundation.layout.Spacer(modifier: Modifier.width(8.dp))
                androidx.compose.foundation.layout.Spacer(modifier: Modifier.weight(Float(1.0)))
            }
            Box {
                ComposeSelectedValue(views: views, context: context, style: style, performsAction: false)
                if isMenu {
                    ComposePickerSelectionMenu(views: views, isExpanded: isMenuExpanded, context: context)
                }
            }
            if style == .navigationLink {
                NavigationLink.ComposeChevron()
            }
        }
    }

    @Composable private func ComposePickerSelectionMenu(views: [TagModifierView], isExpanded: MutableState<Bool>, context: ComposeContext) {
        // Create selectable views from the *content* of each tag view, preserving the enclosing tag
        let menuItems = views.map { tagView in
            let button = Button(action: {
                selection.wrappedValue = tagView.value as! SelectionValue
            }, label: { tagView.view })
            return TagModifierView(view: button, value: tagView.value, role: ComposeModifierRole.tag) as View
        }
        DropdownMenu(expanded: isExpanded.value, onDismissRequest: { isExpanded.value = false }) {
            let coroutineScope = rememberCoroutineScope()
            Menu.ComposeDropdownMenuItems(for: menuItems, selection: selection.wrappedValue, context: context, replaceMenu: { _ in
                coroutineScope.launch {
                    delay(200) // Allow menu item selection animation to be visible
                    isExpanded.value = false
                }
            })
        }
    }

    @Composable private func taggedViews(context: ComposeContext) -> [TagModifierView] {
        var views: [TagModifierView] = []
        EnvironmentValues.shared.setValues {
            $0.set_placement(ViewPlacement.tagged)
        } in: {
            views = content.collectViews(context: context).compactMap { TagModifierView.strip(from: $0, role: ComposeModifierRole.tag) }
        }
        return views
    }

    @Composable private func titleFromLabel(context: ComposeContext) -> Text {
        return label.collectViews(context: context).compactMap { $0.strippingModifiers(perform: { $0 as? Text }) }.first ?? Text(verbatim: String(describing: selection.wrappedValue))
    }
    
    #else
    public var body: some View {
        stubView()
    }
    #endif
}

public struct PickerStyle: RawRepresentable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let automatic = PickerStyle(rawValue: 1)
    public static let navigationLink = PickerStyle(rawValue: 2)
    public static let segmented = PickerStyle(rawValue: 3)
    public static let inline = PickerStyle(rawValue: 4)
    public static let wheel = PickerStyle(rawValue: 5)
    public static let menu = PickerStyle(rawValue: 6)
    public static let palette = PickerStyle(rawValue: 7)
}

extension View {
    public func pickerStyle(_ style: PickerStyle) -> some View {
        #if SKIP
        return environment(\._pickerStyle, style)
        #else
        return self
        #endif
    }
}

#if SKIP
struct PickerSelectionView<SelectionValue> : View {
    let views: [TagModifierView]
    let selection: Binding<SelectionValue>
    let title: Text
    @State private var selectionValue: SelectionValue
    @Environment(\.dismiss) private var dismiss

    init(views: [TagModifierView], selection: Binding<SelectionValue>, title: Text) {
        self.views = views
        self.selection = selection
        self.title = title
        self._selectionValue = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        List {
            ForEach(0..<views.count) { index in
                rowView(label: views[index])
            }
        }
        .navigationTitle(title)
    }

    @ViewBuilder private func rowView(label: TagModifierView) -> some View {
        Button {
            selection.wrappedValue = label.value as! SelectionValue
            selectionValue = selection.wrappedValue // Update the checkmark in the UI while we dismiss
            dismiss()
        } label: {
            HStack {
                // The embedded ZStack allows us to fill the width without a Spacer, which in Compose will share equal space with
                // the label if it also wants to expand to fill space
                ZStack(alignment: .leading) {
                    label
                }
                .frame(maxWidth: .infinity)
                Image(systemName: "checkmark")
                    .foregroundStyle(EnvironmentValues.shared._tint ?? Color.accentColor)
                    .opacity(label.value == selection.wrappedValue ? 1.0 : 0.0)
            }
        }
        .buttonStyle(ButtonStyle.plain)
    }
}
#endif

#if false

// TODO: Process for use in SkipUI

//@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
//extension Picker {
//    /// Creates a picker that displays a custom label.
//    ///
//    /// If the wrapped values of the collection passed to `sources` are not all
//    /// the same, some styles render the selection in a mixed state. The
//    /// specific presentation depends on the style.  For example, a Picker
//    /// with a menu style uses dashes instead of checkmarks to indicate the
//    /// selected values.
//    ///
//    /// In the following example, a picker in a document inspector controls the
//    /// thickness of borders for the currently-selected shapes, which can be of
//    /// any number.
//    ///
//    ///     enum Thickness: String, CaseIterable, Identifiable {
//    ///         case thin
//    ///         case regular
//    ///         case thick
//    ///
//    ///         var id: String { rawValue }
//    ///     }
//    ///
//    ///     struct Border {
//    ///         var color: Color
//    ///         var thickness: Thickness
//    ///     }
//    ///
//    ///     @State private var selectedObjectBorders = [
//    ///         Border(color: .black, thickness: .thin),
//    ///         Border(color: .red, thickness: .thick)
//    ///     ]
//    ///
//    ///     Picker(
//    ///         sources: $selectedObjectBorders,
//    ///         selection: \.thickness
//    ///     ) {
//    ///         ForEach(Thickness.allCases) { thickness in
//    ///             Text(thickness.rawValue)
//    ///         }
//    ///     } label: {
//    ///         Text("Border Thickness")
//    ///     }
//    ///
//    /// - Parameters:
//    ///     - sources: A collection of values used as the source for displaying
//    ///       the Picker's selection.
//    ///     - selection: The key path of the values that determines the
//    ///       currently-selected options. When a user selects an option from the
//    ///       picker, the values at the key path of all items in the `sources`
//    ///       collection are updated with the selected option.
//    ///     - content: A view that contains the set of options.
//    ///     - label: A view that describes the purpose of selecting an option.
//    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
//    public init<C>(sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where C : RandomAccessCollection { fatalError() }
//}
//

#endif
