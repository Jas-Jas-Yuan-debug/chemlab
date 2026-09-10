extends RefCounted

# Source ranges in docs/INDICATORS.md. RGB values are illustrative, not spectra.
static func color_for(index: int, ph: float) -> Color:
    var clear := Color(0.91,0.96,0.97,0.08)
    if index==1:
        if ph<2.0 or ph>11.5:
            return clear
        return clear.lerp(Color(0.92,0.12,0.53,0.70),clampf((ph-8.3)/1.5,0,1))
    if index==2:
        return Color(0.94,0.12,0.07,0.70).lerp(Color(1.0,0.72,0.05,0.68),clampf((ph-3.1)/1.3,0,1))
    if index==3:
        # Interpolate through green to represent the observed neutral mixture.
        var x := clampf((ph-6.0)/1.6,0,1)
        if x<0.5:
            return Color(0.95,0.82,0.09,0.65).lerp(Color(0.18,0.68,0.32,0.65),x*2)
        return Color(0.18,0.68,0.32,0.65).lerp(Color(0.05,0.24,0.83,0.65),(x-0.5)*2)
    return clear
