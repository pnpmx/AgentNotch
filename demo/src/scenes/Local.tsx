import {Interactive, interpolate, useCurrentFrame, Easing} from "remotion";
import {Frame, Mic} from "../ui";

export const Local = () => {
  const frame = useCurrentFrame();
  return <Frame duration={180} dark>
    <Interactive.Div name="Local processing headline" style={{position: "absolute", top: 154, left: 200, right: 200, textAlign: "center", fontSize: 76, fontWeight: 600, letterSpacing: -3}}>Your voice. On your Mac.</Interactive.Div>
    <Interactive.Div name="Local processing subtitle" style={{position: "absolute", top: 259, left: 200, right: 200, textAlign: "center", fontSize: 30, color: "#98989d"}}>On-device speech. No speech-to-text API key.</Interactive.Div>
    <Interactive.Div name="Speech processor" style={{position: "absolute", left: 785, top: 435, width: 350, height: 290, borderRadius: 40, background: "linear-gradient(145deg, #303034, #111113)", border: "1px solid #55555c", boxShadow: "0 0 100px #ffffff08, inset 0 1px 0 #ffffff30", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 23, scale: interpolate(frame, [0, 50], [0.94, 1], {extrapolateRight: "clamp", output: "perceptual-scale", easing: Easing.bezier(0.22, 1, 0.36, 1)})}}>
      <Mic color="#e5e5ea" size={55} /><div style={{fontSize: 29, fontWeight: 500, letterSpacing: -0.6}}>SpeechAnalyzer</div><div style={{fontSize: 18, color: "#86868b"}}>Processed locally</div>
    </Interactive.Div>
    <Interactive.Div name="Voice input" style={{position: "absolute", left: 408, top: 526, width: 220, textAlign: "center"}}>
      <div style={{height: 70, display: "flex", alignItems: "center", justifyContent: "center", gap: 7}}>{Array.from({length: 15}, (_, i) => <div key={i} style={{width: 5, borderRadius: 5, background: "#d1d1d6", height: 8 + 42 * Math.abs(Math.sin(frame * 0.075 + i * 0.55))}} />)}</div><div style={{fontSize: 23, color: "#98989d", marginTop: 23}}>Your voice</div>
    </Interactive.Div>
    <div style={{position: "absolute", left: 666, top: 578, width: 80, height: 1, background: "#55555c"}} />
    <div style={{position: "absolute", left: 1174, top: 578, width: 80, height: 1, background: "#55555c"}} />
    <Interactive.Div name="Text output" style={{position: "absolute", left: 1292, top: 526, width: 220, textAlign: "center"}}>
      <div style={{height: 70, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", gap: 10}}>{[126, 154, 100].map((width, i) => <div key={i} style={{width, height: 5, borderRadius: 5, background: "#d1d1d6", opacity: interpolate(frame, [30 + i * 10, 50 + i * 10], [0.15, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}} />)}</div><div style={{fontSize: 23, color: "#98989d", marginTop: 23}}>Your text</div>
    </Interactive.Div>
    <Interactive.Div name="Connectivity disclosure" style={{position: "absolute", left: 200, right: 200, top: 869, textAlign: "center", fontSize: 20, lineHeight: 1.6, color: "#86868b"}}>Initial language downloads may require a connection.<br />Codex and Claude usage integrations use their services.</Interactive.Div>
  </Frame>;
};

