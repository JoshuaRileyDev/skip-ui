// This is free software: you can redistribute and/or modify it
// under the terms of the GNU Lesser General Public License 3.0
// as published by the Free Software Foundation https://fsf.org

#if SKIP
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
#endif

public struct Divider : View {
    public init() {
    }

    #if SKIP
    /*
     https://cs.android.com/androidx/platform/frameworks/support/+/androidx-main:compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/Divider.kt
     @Composable
     fun Divider(
        modifier: Modifier = Modifier,
        thickness: Dp = DividerDefaults.Thickness,
        color: Color = DividerDefaults.color,
     )
     */
    @Composable public override func ComposeContent(context: ComposeContext) {
        let dividerColor = androidx.compose.ui.graphics.Color.LightGray
        let modifier: Modifier
        if EnvironmentValues.shared._fillWidthModifier != nil {
            // If in a horizontal container, create a vertical divider
            modifier = Modifier.width(1.dp).then(context.modifier.fillHeight())
        } else {
            modifier = context.modifier
        }
        androidx.compose.material3.Divider(modifier: modifier, color: dividerColor)
    }
    #else
    public var body: some View {
        stubView()
    }
    #endif
}
