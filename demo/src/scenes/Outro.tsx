import {Interactive, interpolate, useCurrentFrame, Easing} from "remotion";
import {Frame} from "../ui";

export const Outro = () => {
  const frame = useCurrentFrame();
  return <Frame duration={180}>
    <Interactive.Div name="Notch mark" style={{position: "absolute", left: 881, top: 281, width: 158, height: 59, borderRadius: "0 0 26px 26px", background: "#1d1d1f", scale: interpolate(frame, [0, 35], [0.9, 1], {extrapolateRight: "clamp", output: "perceptual-scale", easing: Easing.bezier(0.22, 1, 0.36, 1)})}} />
    <Interactive.Div name="Closing product name" style={{position: "absolute", top: 397, left: 200, right: 200, textAlign: "center", fontSize: 92, fontWeight: 600, letterSpacing: -4}}>AgentNotch</Interactive.Div>
    <Interactive.Div name="Closing promise" style={{position: "absolute", top: 523, left: 200, right: 200, textAlign: "center", fontSize: 34, letterSpacing: -0.7, color: "#86868b"}}>Less switching. Keep creating.</Interactive.Div>
    <Interactive.Div name="Repository" style={{position: "absolute", top: 661, left: 200, right: 200, textAlign: "center", fontSize: 28, color: "#1d1d1f", opacity: interpolate(frame, [30, 55], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>github.com/pnpmx/AgentNotch ↗</Interactive.Div>
    <Interactive.Div name="Platform requirements" style={{position: "absolute", top: 840, left: 200, right: 200, textAlign: "center", fontSize: 21, color: "#86868b"}}>Open source · MIT · macOS 26+ · Apple Silicon</Interactive.Div>
  </Frame>;
};

