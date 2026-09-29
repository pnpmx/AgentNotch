import {Interactive, interpolate, useCurrentFrame, Easing} from "remotion";
import {Frame, Notch, Disclosure} from "../ui";

export const Intro = () => {
  const frame = useCurrentFrame();
  return <Frame duration={150}>
    <Interactive.Div name="Product name" style={{position: "absolute", top: 152, left: 200, right: 200, textAlign: "center", fontSize: 92, fontWeight: 600, letterSpacing: -4, translate: interpolate(frame, [0, 35], ["0px 18px", "0px 0px"], {extrapolateRight: "clamp", easing: Easing.bezier(0.22, 1, 0.36, 1)})}}>AgentNotch</Interactive.Div>
    <Interactive.Div name="Opening promise" style={{position: "absolute", top: 278, left: 200, right: 200, textAlign: "center", fontSize: 34, fontWeight: 400, letterSpacing: -0.8, color: "#86868b", opacity: interpolate(frame, [15, 38], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>A little space. A better workflow.</Interactive.Div>
    <Interactive.Div name="Mac display" style={{position: "absolute", left: 380, top: 402, width: 1160, height: 480, boxSizing: "border-box", borderRadius: 30, border: "9px solid #252528", background: "linear-gradient(135deg, #e8e8ed, #fafafa 55%, #dedee5)", boxShadow: "0 45px 80px -35px #00000045", overflow: "hidden", scale: interpolate(frame, [0, 145], [0.94, 1], {extrapolateRight: "clamp", output: "perceptual-scale", easing: Easing.bezier(0.22, 1, 0.36, 1)})}}>
      <div style={{position: "absolute", left: 161, top: 0}}><Notch /></div>
      <div style={{position: "absolute", left: 191, right: 191, top: 169, height: 229, borderRadius: 17, background: "#ffffffdc", border: "1px solid #fff", boxShadow: "0 12px 30px #0000000d", padding: 29, boxSizing: "border-box"}}>
        <div style={{display: "flex", gap: 7}}>{[0, 1, 2].map(i => <span key={i} style={{width: 9, height: 9, borderRadius: 9, background: "#d1d1d6"}} />)}</div>
        <div style={{marginTop: 27, fontSize: 25, fontWeight: 500, color: "#6e6e73"}}>What are we building?</div>
        <div style={{marginTop: 25, width: 366, height: 6, background: "#e5e5ea", borderRadius: 5}} />
        <div style={{marginTop: 12, width: 251, height: 6, background: "#ededf0", borderRadius: 5}} />
      </div>
    </Interactive.Div>
    <Disclosure />
  </Frame>;
};

