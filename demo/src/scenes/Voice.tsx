import {Interactive, interpolate, useCurrentFrame} from "remotion";
import {Frame, Notch, Disclosure} from "../ui";

export const Voice = () => {
  const frame = useCurrentFrame();
  const listening = frame >= 48 && frame < 153;
  const processing = frame >= 153 && frame < 179;
  const pasted = frame >= 179;
  return <Frame duration={270}>
    <Interactive.Div name="Dictation headline" style={{position: "absolute", top: 119, left: 200, right: 200, textAlign: "center", fontSize: 76, letterSpacing: -3, fontWeight: 600}}>Hold. Speak. Release.</Interactive.Div>
    <Interactive.Div name="Recording indicator" style={{position: "absolute", left: 550, top: 270}}><Notch listening={listening} processing={processing} /></Interactive.Div>
    <Interactive.Div name="Illustrated prompt editor" style={{position: "absolute", left: 500, top: 422, width: 920, height: 307, background: "#fff", border: "1px solid #dedee3", borderRadius: 24, padding: 34, boxSizing: "border-box", boxShadow: "0 18px 60px -35px #00000035"}}>
      <div style={{fontSize: 18, color: "#86868b", letterSpacing: 1.5}}>CODEX · PROMPT</div>
      <Interactive.Div name="Dictated text" style={{position: "absolute", left: 34, right: 34, top: 101, fontSize: 37, lineHeight: 1.3, letterSpacing: -1, color: pasted ? "#1d1d1f" : "#b0b0b5", opacity: pasted ? interpolate(frame, [179, 192], [0, 1], {extrapolateRight: "clamp"}) : 1}}>{pasted ? "Let's build something great." : "What are we building?"}</Interactive.Div>
      <div style={{position: "absolute", left: 34, bottom: 31, display: "flex", alignItems: "center", gap: 10, fontSize: 20, color: listening ? "#e5484d" : "#86868b"}}><span style={{width: 7, height: 7, borderRadius: 8, background: listening ? "#ff453a" : "#98989d"}} />{listening ? "Listening…" : processing ? "Transcribing on your Mac…" : pasted ? "Pasted into your prompt." : "Ready when you are."}</div>
      {listening && <div style={{position: "absolute", right: 34, bottom: 28, height: 26, display: "flex", alignItems: "center", gap: 4}}>{Array.from({length: 21}, (_, i) => <div key={i} style={{width: 3, borderRadius: 3, background: "#ff453a", height: 4 + 20 * Math.abs(Math.sin(frame * 0.23 + i * 0.72))}} />)}</div>}
    </Interactive.Div>
    <Interactive.Div name="Space key" style={{position: "absolute", left: 800, top: 792, width: 320, height: 66, borderRadius: 13, border: "1px solid #d2d2d7", background: listening ? "#242426" : "#fff", color: listening ? "#fff" : "#6e6e73", boxShadow: listening ? "0 2px 0 #b5b5ba" : "0 6px 0 #d2d2d7", display: "grid", placeItems: "center", fontSize: 24, translate: interpolate(frame, [38, 48, 147, 153], ["0px 0px", "0px 4px", "0px 4px", "0px 0px"], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>space</Interactive.Div>
    <Interactive.Div name="Keyboard instruction" style={{position: "absolute", left: 200, right: 200, top: 902, textAlign: "center", fontSize: 25, color: "#86868b"}}>{listening ? "The red microphone means you're recording." : pasted ? "Your words. Right where you need them." : "Hold to talk. Release to paste."}</Interactive.Div>
    <Disclosure />
  </Frame>;
};

