import {Interactive, interpolate, useCurrentFrame, Easing} from "remotion";
import {Frame, Notch, Cursor, Disclosure} from "../ui";

export const Usage = () => {
  const frame = useCurrentFrame();
  return <Frame duration={240}>
    <Interactive.Div name="Usage headline" style={{position: "absolute", top: 143, left: 200, right: 200, textAlign: "center", fontSize: 76, fontWeight: 600, letterSpacing: -3}}>Your limits. At a glance.</Interactive.Div>
    <Interactive.Div name="Usage subtitle" style={{position: "absolute", top: 246, left: 200, right: 200, textAlign: "center", fontSize: 30, color: "#86868b"}}>Codex and Claude Code, right beside your camera.</Interactive.Div>
    <Interactive.Div name="Centered usage panel" style={{position: "absolute", left: 550, top: 340, translate: interpolate(frame, [0, 30], ["0px 16px", "0px 0px"], {extrapolateRight: "clamp", easing: Easing.bezier(0.22, 1, 0.36, 1)})}}><Notch expanded /></Interactive.Div>
    <Interactive.Div name="Click to expand" style={{position: "absolute", left: 724, top: 391, opacity: interpolate(frame, [10, 20, 36, 50], [0, 1, 1, 0], {extrapolateLeft: "clamp", extrapolateRight: "clamp"}), translate: interpolate(frame, [10, 34], ["70px 80px", "0px 0px"], {extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.22, 1, 0.36, 1)})}}><Cursor /></Interactive.Div>
    <Interactive.Div name="Reset caption" style={{position: "absolute", left: 200, right: 200, top: 885, textAlign: "center", fontSize: 28, color: "#6e6e73", opacity: interpolate(frame, [85, 105], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>Usage. Reset times. One quiet glance.</Interactive.Div>
    <Disclosure />
  </Frame>;
};
