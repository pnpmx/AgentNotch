import {Composition, Folder, Series, staticFile} from "remotion";
import {Audio} from "@remotion/media";
import {Intro} from "./scenes/Intro";
import {Usage} from "./scenes/Usage";
import {Voice} from "./scenes/Voice";
import {Local} from "./scenes/Local";
import {Outro} from "./scenes/Outro";

const AgentNotchDemo = () => <>
  <Audio src={staticFile("audio/agentnotch-score.wav")} />
  <Series>
  <Series.Sequence name="Meet AgentNotch" durationInFrames={150}><Intro /></Series.Sequence>
  <Series.Sequence name="Usage at a glance" durationInFrames={240}><Usage /></Series.Sequence>
  <Series.Sequence name="Hold to speak" durationInFrames={270}><Voice /></Series.Sequence>
  <Series.Sequence name="On-device speech" durationInFrames={180}><Local /></Series.Sequence>
  <Series.Sequence name="Open source" durationInFrames={180}><Outro /></Series.Sequence>
</Series>
</>;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="AgentNotchDemo" component={AgentNotchDemo} durationInFrames={1020} fps={30} width={1920} height={1080} />
      <Folder name="Scenes">
        <Composition id="Intro" component={Intro} durationInFrames={150} fps={30} width={1920} height={1080} />
        <Composition id="Usage" component={Usage} durationInFrames={240} fps={30} width={1920} height={1080} />
        <Composition id="Voice" component={Voice} durationInFrames={270} fps={30} width={1920} height={1080} />
        <Composition id="Local" component={Local} durationInFrames={180} fps={30} width={1920} height={1080} />
        <Composition id="Outro" component={Outro} durationInFrames={180} fps={30} width={1920} height={1080} />
      </Folder>
    </>
  );
};
