import React from "react";
import {AbsoluteFill, Easing, Interactive, interpolate, useCurrentFrame} from "remotion";

export const Frame: React.FC<{children: React.ReactNode; duration: number; dark?: boolean}> = ({children, duration, dark = false}) => {
  const frame = useCurrentFrame();
  return <AbsoluteFill style={{background: dark ? "#08080a" : "#f5f5f7", color: dark ? "#f5f5f7" : "#1d1d1f", fontFamily: '-apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif', overflow: "hidden"}}>
    <AbsoluteFill style={{opacity: interpolate(frame, [0, 16, duration - 16, duration - 1], [0, 1, 1, 0], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>
      {children}
    </AbsoluteFill>
  </AbsoluteFill>;
};

export const Mic: React.FC<{color?: string; size?: number}> = ({color = "#ff453a", size = 32}) => (
  <svg width={size} height={size} viewBox="0 0 32 32" fill="none">
    <rect x="11" y="3" width="10" height="17" rx="5" fill={color} />
    <path d="M7 15a9 9 0 0 0 18 0M16 24v5M11 29h10" stroke={color} strokeWidth="2.5" strokeLinecap="round" />
  </svg>
);

const Ring: React.FC<{progress: number; color: string}> = ({progress, color}) => (
  <svg width="36" height="36" viewBox="0 0 44 44" style={{rotate: "-90deg"}}>
    <circle cx="22" cy="22" r="17" fill="none" stroke="#343438" strokeWidth="4" />
    <circle cx="22" cy="22" r="17" fill="none" stroke={color} strokeWidth="4" strokeDasharray="106.8" strokeDashoffset={106.8 * (1 - progress)} strokeLinecap="round" />
  </svg>
);

export const Notch: React.FC<{expanded?: boolean; listening?: boolean; processing?: boolean}> = ({expanded = false, listening = false, processing = false}) => {
  const frame = useCurrentFrame();
  return <Interactive.Div name="AgentNotch product UI" style={{width: 820, height: expanded ? interpolate(frame, [34, 66], [96, 492], {extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.bezier(0.22, 1, 0.36, 1)}) : 96, background: "#000000", borderRadius: "0 0 36px 36px", color: "#f5f5f7", overflow: "hidden", boxShadow: "0 28px 60px -18px #00000038", textAlign: "left"}}>
    <div style={{height: 96, display: "grid", gridTemplateColumns: "260px 300px 260px", alignItems: "center"}}>
      <div style={{display: "flex", gap: 14, paddingLeft: 30, alignItems: "center"}}>
        {listening ? <div style={{width: 36, height: 36, display: "grid", placeItems: "center", opacity: 0.6 + 0.4 * Math.cos(frame * Math.PI / 15)}}><Mic /></div> : processing ? <span style={{width: 36, color: "#ff9f0a", fontSize: 28, textAlign: "center"}}>···</span> : <Ring progress={0.24} color="#00c7be" />}
        <div><div style={{fontSize: 24, fontWeight: 600}}>Codex</div><div style={{fontSize: 20, color: "#98989d", marginTop: 3}}>24%</div></div>
      </div>
      <div aria-label="Reserved physical camera area" style={{alignSelf: "start", height: 72, background: "#000"}} />
      <div style={{display: "flex", justifyContent: "flex-end", paddingRight: 30, gap: 14, alignItems: "center"}}>
        <Ring progress={0.61} color="#ff9f0a" /><div><div style={{fontSize: 24, fontWeight: 600}}>Claude</div><div style={{fontSize: 20, color: "#98989d", marginTop: 3}}>61%</div></div>
      </div>
    </div>
    {expanded && <div style={{padding: "0 30px 24px", opacity: interpolate(frame, [49, 76], [0, 1], {extrapolateLeft: "clamp", extrapolateRight: "clamp"})}}>
      <div style={{height: 1, background: "#ffffff40", marginBottom: 22}} />
      <div style={{display: "flex", alignItems: "center", gap: 12, fontSize: 21, fontWeight: 600, marginBottom: 26}}><Mic color="#fff" size={26} />Mantén Space <span style={{marginLeft: "auto", color: "#777", fontSize: 19}}>Space · 280 ms</span><svg width="16" height="12" viewBox="0 0 16 12"><path d="M1 9L8 2L15 9" fill="none" stroke="white" strokeWidth="2" /></svg></div>
      <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: 30}}>
        {[
          {name: "Codex", color: "#00c7be", source: "Codex CLI · hace 0 min", windows: [{label: "7 días", value: 24, reset: "5 d 19 h"}]},
          {name: "Claude Code", color: "#ff9f0a", source: "Claude Code · hace 0 min", windows: [{label: "5 horas", value: 61, reset: "2 h 10 min"}, {label: "7 días", value: 68, reset: "2 d 16 h"}]},
        ].map(item => <div key={item.name}>
          <div style={{fontSize: 24, fontWeight: 700, color: item.color}}>{item.name}</div>
          <div style={{fontSize: 18, color: "#929292", marginTop: 12, marginBottom: 15}}>{item.source}</div>
          {item.windows.map(window => <div key={window.label} style={{marginBottom: 17}}>
            <div style={{display: "flex", justifyContent: "space-between", fontSize: 20, fontWeight: 600}}><span>{window.label}</span><span>{window.value}%</span></div>
            <div style={{height: 10, borderRadius: 10, background: "#191919", marginTop: 8}}><div style={{height: "100%", width: window.value + "%", borderRadius: 10, background: "#a6a6a6"}} /></div>
            <div style={{fontSize: 18, marginTop: 7, color: "#868686"}}>reset {window.reset}</div>
          </div>)}
        </div>)}
      </div>
      <div style={{display: "flex", alignItems: "center", gap: 10, marginTop: 7, fontSize: 24, color: "#d1d1d1"}}>
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="12" r="10" /><ellipse cx="12" cy="12" rx="4" ry="10" /><path d="M2 12h20M4 6h16M4 18h16" /></svg>
        Español <svg width="13" height="9" viewBox="0 0 13 9"><path d="M1 1L6.5 7L12 1" fill="none" stroke="currentColor" strokeWidth="2" /></svg>
        <svg style={{marginLeft: "auto"}} width="27" height="29" viewBox="0 0 27 29" fill="none" stroke="currentColor" strokeWidth="2"><path d="M20 8a10 10 0 1 0 3 8M15 2l6 5-6 5" strokeLinecap="round" strokeLinejoin="round" /></svg>
      </div>
    </div>}
  </Interactive.Div>;
};

export const Cursor = () => <svg width="32" height="40" viewBox="0 0 32 40" fill="white" stroke="#1d1d1f" strokeWidth="2"><path d="M3 2v30l8-8 7 13 6-3-7-13h12L3 2Z" /></svg>;

export const Disclosure = () => <Interactive.Div name="Illustration disclosure" style={{position: "absolute", bottom: 65, left: 200, right: 200, textAlign: "center", fontSize: 18, color: "#86868b"}}>Illustrated interface · sample usage</Interactive.Div>;
