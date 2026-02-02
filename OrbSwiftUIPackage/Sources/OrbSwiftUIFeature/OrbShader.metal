#include <metal_stdlib>
using namespace metal;

// Hash functions for noise
float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(dot(hash2(i + float2(0.0, 0.0)), f - float2(0.0, 0.0)),
            dot(hash2(i + float2(1.0, 0.0)), f - float2(1.0, 0.0)), u.x),
        mix(dot(hash2(i + float2(0.0, 1.0)), f - float2(0.0, 1.0)),
            dot(hash2(i + float2(1.0, 1.0)), f - float2(1.0, 1.0)), u.x),
        u.y
    );
}

float fbm2(float2 p) {
    float value = noise(p) * 0.5;
    p *= 2.0;
    value += noise(p) * 0.25;
    return value;
}

float fbm3(float2 p) {
    float value = noise(p) * 0.5;
    p *= 2.0;
    value += noise(p) * 0.25;
    p *= 2.0;
    value += noise(p) * 0.125;
    return value;
}

float fbm4(float2 p) {
    float value = noise(p) * 0.5;
    p *= 2.0;
    value += noise(p) * 0.25;
    p *= 2.0;
    value += noise(p) * 0.125;
    p *= 2.0;
    value += noise(p) * 0.0625;
    return value;
}

float circularNoise3(float angle, float noiseScale, float timeOffset) {
    float2 circlePos = float2(cos(angle), sin(angle)) * noiseScale;
    return fbm3(circlePos + float2(timeOffset));
}

float circularNoise4(float angle, float noiseScale, float timeOffset) {
    float2 circlePos = float2(cos(angle), sin(angle)) * noiseScale;
    return fbm4(circlePos + float2(timeOffset));
}

float metaball(float2 uv, float2 center, float radius, float softness) {
    float2 delta = uv - center;
    float distSq = dot(delta, delta);
    if (distSq > 0.25) return 0.0;
    float dist = sqrt(distSq);
    float blob = radius / (dist + 0.001);
    return pow(clamp(blob, 0.0, 1.0), softness);
}

// Main orb shader - stitchable for SwiftUI .colorEffect
[[ stitchable ]] half4 orbShader(
    float2 position,
    half4 currentColor,
    float2 size,
    float uTime,
    float uIntensity,
    float uIsRecording,
    float uStage,
    float uStageProgress,
    float2 uTilt
) {
    constexpr float PI = 3.14159265358979323846;

    float2 uResolution = size;
    float2 uv = (position / uResolution) * 2.0 - 1.0;
    float aspect = uResolution.x / uResolution.y;
    uv.x *= aspect;

    float radius = length(uv);
    if (radius > 0.85) return half4(0.0);

    float angle = atan2(uv.y, uv.x);
    float time = uTime * 0.4;

    float2 ringUv = uv - uTilt * 0.08 * 0.3;
    float ringRadius = length(ringUv);
    float ringAngle = atan2(ringUv.y, ringUv.x);

    // State factors
    float idleFactor = smoothstep(0.5, 0.0, uStage);
    float transcribingFactor = smoothstep(0.0, 0.5, uStage) * smoothstep(1.5, 1.0, uStage);
    float thinkingFactor = smoothstep(1.0, 1.5, uStage) * smoothstep(2.5, 2.0, uStage);
    float completeFactor = smoothstep(2.0, 2.5, uStage);

    float transcribeRotation = uTime * 0.6 * transcribingFactor;
    float transcribePulse = (sin(uTime * 5.0) * 0.5 + 0.5) * transcribingFactor;
    float thinkingConverge = 0.7 + 0.3 * (1.0 - thinkingFactor);
    float completeBrightness = 1.0 + completeFactor * 0.15;

    // IDLE animations
    float idleBreathPrimary = sin(uTime * 0.8) * 0.5 + 0.5;
    float idleBreathSecondary = sin(uTime * 1.3 + 0.5) * 0.3 + 0.5;
    float idleBreathCombined = mix(idleBreathPrimary, idleBreathSecondary, 0.3) * idleFactor;

    float heartbeat1 = pow(sin(uTime * 1.2), 8.0);
    float heartbeat2 = pow(sin(uTime * 1.2 + 0.15), 8.0) * 0.6;
    float heartbeatPulse = (heartbeat1 + heartbeat2) * idleFactor * 0.15;

    float curiousTrigger = smoothstep(0.95, 1.0, sin(uTime * 0.08)) * idleFactor;
    float curiousAngle = noise(float2(floor(uTime * 0.1), 0.0)) * 2.0 * PI;
    float curiousDecay = exp(-fract(uTime * 0.08) * 5.0);
    float2 curiousOffset = float2(cos(curiousAngle), sin(curiousAngle)) * 0.03 * curiousTrigger * curiousDecay;

    // TRANSCRIBING animations
    float rippleSpeed = 3.0;
    float rippleCount = 3.0;
    float rippleWave = sin(radius * rippleCount * PI - uTime * rippleSpeed) * 0.5 + 0.5;
    float rippleIntensity = uIntensity * transcribingFactor * 0.12;
    float2 listeningFocus = -uTilt * 0.04 * transcribingFactor * uIntensity;

    // THINKING animations
    float spiralSpeed = 0.4 * thinkingFactor;
    float spiralAngle = uTime * spiralSpeed;
    float2x2 spiralRotation = float2x2(
        cos(spiralAngle), -sin(spiralAngle),
        sin(spiralAngle), cos(spiralAngle)
    );
    float thinkingBuildUp = min(uStageProgress * 2.0, 1.0);
    float computePulse = sin(uTime * 3.0 + thinkingBuildUp * PI) * 0.5 + 0.5;
    float computeIntensity = computePulse * thinkingFactor * thinkingBuildUp * 0.2;
    float thinkBreath = sin(uTime * (0.6 * (1.0 + uStageProgress * 0.3))) * 0.1 * thinkingFactor;

    // COMPLETE animations
    float burstPhase = smoothstep(0.0, 0.4, uStageProgress);
    float burstDecay = 1.0 - burstPhase;
    float burstIntensityVal = burstDecay * completeFactor;
    float burstExpansion = 1.0 + burstIntensityVal * 0.12;
    float burstBrightnessVal = burstIntensityVal * 0.25;
    float invitationGlowStrength = completeFactor * 0.15;
    float2 glowDirection = -uTilt * 0.08;
    float directionalGlow = smoothstep(0.5, 0.0, length(uv - glowDirection)) * invitationGlowStrength;
    float2 contentmentSway = float2(sin(uTime * 0.3) * 0.015, cos(uTime * 0.25) * 0.012) * completeFactor;
    float coreStability = 1.0 - completeFactor * 0.6;

    // Voice reactivity
    float smoothIntensity = uIntensity * uIntensity;
    float voiceInfluence = uIsRecording * smoothIntensity;
    float voiceAmplitude = 1.0 + voiceInfluence * 0.25;
    float voicePulseDepth = 1.0 + voiceInfluence * 0.3;
    float wobbleStrength = voiceInfluence * 0.06;
    float2 voiceWobble = float2(
        noise(float2(uTime * 3.0, 0.0)) * wobbleStrength,
        noise(float2(uTime * 3.0, 100.0)) * wobbleStrength
    );
    float2 fragWobble = float2(
        noise(float2(uTime * 4.0, 200.0)) * voiceInfluence * 0.1,
        noise(float2(uTime * 4.0, 300.0)) * voiceInfluence * 0.1
    );

    float sizeBoost = 1.0 + smoothIntensity * 0.35;
    float spreadBoost = (1.0 + smoothIntensity * 0.2) * thinkingConverge * (1.0 + completeFactor * 0.15);
    float glowBoost = (1.0 + smoothIntensity * 0.3) * completeBrightness;
    float breakawayPhase = sin(uTime * 0.15) * 0.5 + 0.5;
    float breakawayStrength = 0.3 + breakawayPhase * 0.4 + voiceInfluence * 0.4;

    // Parallax
    float parallaxStrength = 0.10;
    float2 cell1Parallax = uTilt * parallaxStrength * 0.3;
    float2 cell2Parallax = uTilt * parallaxStrength * 0.5;
    float2 cell3Parallax = uTilt * parallaxStrength * 0.7;
    float2 cell4Parallax = uTilt * parallaxStrength * 0.6;
    float2 cell5Parallax = uTilt * parallaxStrength * 0.4;
    float2 frag1Parallax = uTilt * parallaxStrength * 0.9;
    float2 frag2Parallax = uTilt * parallaxStrength * 1.0;
    float2 frag3Parallax = uTilt * parallaxStrength * 1.2;
    float2 frag4Parallax = uTilt * parallaxStrength * 0.95;
    float2 frag5Parallax = uTilt * parallaxStrength * 0.85;
    float2 frag6Parallax = uTilt * parallaxStrength * 1.3;
    float2 frag7Parallax = uTilt * parallaxStrength * 1.25;
    float2 coreParallax = uTilt * parallaxStrength * -0.5;
    float2 innerGlowParallax = uTilt * parallaxStrength * 1.4;

    // Inner glow layer
    float innerGlowScale = 0.7;
    float innerGlowSoftness = 2.5;
    float2 innerGlowUv = uv - innerGlowParallax;
    float innerGlowField = 0.0;
    innerGlowField += metaball(innerGlowUv, float2(sin(uTime*0.12)*0.08, cos(uTime*0.1)*0.06)*spreadBoost + innerGlowParallax, 0.06*innerGlowScale*sizeBoost, innerGlowSoftness);
    innerGlowField += metaball(innerGlowUv, float2(cos(uTime*0.15+0.5)*0.12, sin(uTime*0.13+0.5)*0.1)*spreadBoost + innerGlowParallax, 0.045*innerGlowScale*sizeBoost, innerGlowSoftness);
    innerGlowField += metaball(innerGlowUv, float2(sin(uTime*0.18+2.0)*0.1, cos(uTime*0.16+1.5)*0.08)*spreadBoost + innerGlowParallax, 0.04*innerGlowScale*sizeBoost, innerGlowSoftness);
    float innerGlow = smoothstep(0.3, 0.6, innerGlowField) * 0.25;

    // State combined modifiers
    float2 stateOffset = curiousOffset + contentmentSway + listeningFocus;
    float breathScale = 1.0 + idleBreathCombined * 0.06 + thinkBreath;
    float stateExpansion = burstExpansion * breathScale;

    // Main cells
    float cellField = 0.0;

    // Cell 1
    float pulse1 = 1.0 + sin(uTime*0.8)*0.15*voicePulseDepth + heartbeatPulse;
    float2 pos1Base = float2(sin(uTime*0.12)*0.12, cos(uTime*0.1)*0.1) * spreadBoost * voiceAmplitude;
    float2 pos1Rotated = thinkingFactor > 0.01 ? spiralRotation * pos1Base : pos1Base;
    float2 pos1 = mix(pos1Base, pos1Rotated, thinkingFactor) * stateExpansion + voiceWobble + cell1Parallax + stateOffset;
    cellField += metaball(uv, pos1, 0.09*pulse1*sizeBoost*breathScale, 1.8);

    // Cell 2
    float pulse2 = 1.0 + sin(uTime*1.1+1.0)*0.12*voicePulseDepth + heartbeatPulse*0.8;
    float stretch2 = 1.0 + sin(uTime*0.4)*(0.3 + voiceInfluence*0.2);
    float2 pos2Base = float2(cos(uTime*0.15+0.5)*0.2*stretch2, sin(uTime*0.13+0.5)*0.16) * spreadBoost * voiceAmplitude;
    float2 pos2Rotated = thinkingFactor > 0.01 ? spiralRotation * pos2Base : pos2Base;
    float2 pos2 = mix(pos2Base, pos2Rotated, thinkingFactor) * stateExpansion + voiceWobble*0.8 + cell2Parallax + stateOffset*0.9;
    cellField += metaball(uv, pos2, 0.07*pulse2*sizeBoost*breathScale, 2.0);

    // Cell 3
    float pulse3 = 1.0 + sin(uTime*1.4+2.0)*0.1*voicePulseDepth + heartbeatPulse*0.6;
    float separate3 = smoothstep(0.3, 0.7, sin(uTime*0.2+1.0)) + voiceInfluence*0.25;
    float2 pos3Base = float2(sin(uTime*0.18+2.0)*(0.18+separate3*0.12), cos(uTime*0.16+1.5)*(0.15+separate3*0.1)) * spreadBoost * voiceAmplitude;
    float2 pos3Rotated = thinkingFactor > 0.01 ? spiralRotation * pos3Base : pos3Base;
    float2 pos3 = mix(pos3Base, pos3Rotated, thinkingFactor) * stateExpansion + voiceWobble + cell3Parallax + stateOffset;
    cellField += metaball(uv, pos3, 0.055*pulse3*sizeBoost, 2.2);

    // Cell 4
    float pulse4 = 1.0 + sin(uTime*0.9+3.0)*0.13*voicePulseDepth + heartbeatPulse*0.7;
    float2 pos4Base = float2(sin(uTime*0.14)*cos(uTime*0.07)*0.24, cos(uTime*0.11)*0.14) * spreadBoost * voiceAmplitude;
    float2 pos4Rotated = thinkingFactor > 0.01 ? spiralRotation * pos4Base : pos4Base;
    float2 pos4 = mix(pos4Base, pos4Rotated, thinkingFactor) * stateExpansion + voiceWobble*0.6 + cell4Parallax + stateOffset*0.85;
    cellField += metaball(uv, pos4, 0.06*pulse4*sizeBoost*breathScale, 2.1);

    // Cell 5
    float pulse5 = 1.0 + sin(uTime*0.6+5.0)*0.18*voicePulseDepth + heartbeatPulse*0.5;
    float2 pos5Base = float2(cos(uTime*0.08+4.0)*0.14, sin(uTime*0.09+3.5)*0.18) * spreadBoost * voiceAmplitude;
    float2 pos5Rotated = thinkingFactor > 0.01 ? spiralRotation * pos5Base : pos5Base;
    float2 pos5 = mix(pos5Base, pos5Rotated, thinkingFactor) * stateExpansion + voiceWobble*0.9 + cell5Parallax + stateOffset*0.95;
    cellField += metaball(uv, pos5, 0.065*pulse5*sizeBoost*breathScale, 1.9);

    // Fragments
    float fragmentField = 0.0;
    float fragAmplitude = voiceAmplitude * (1.0 + voiceInfluence * 0.15);

    float detach1 = smoothstep(0.4, 0.8, sin(uTime*0.25)) + voiceInfluence*0.3;
    float2 fragPos1 = pos2 + float2(cos(uTime*0.3+1.0)*0.08*(1.0+detach1*breakawayStrength), sin(uTime*0.35+0.5)*0.06*(1.0+detach1*breakawayStrength))*fragAmplitude + fragWobble + frag1Parallax;
    fragmentField += metaball(uv, fragPos1, 0.025*(0.8+detach1*0.4)*sizeBoost, 2.5);

    float detach2 = smoothstep(0.5, 0.9, sin(uTime*0.18+2.0));
    float orbitRadius2 = 0.22 + detach2*0.15*breakawayStrength + voiceInfluence*0.06;
    float2 fragPos2 = float2(cos(uTime*0.4+2.5)*orbitRadius2, sin(uTime*0.45+2.0)*orbitRadius2*0.8)*spreadBoost*fragAmplitude + fragWobble + frag2Parallax;
    fragmentField += metaball(uv, fragPos2, 0.022*sizeBoost, 2.8);

    float detach3 = smoothstep(0.3, 0.7, sin(uTime*0.3+1.5));
    float reach3 = 1.0 + voiceInfluence*0.2;
    float2 fragPos3 = float2(sin(uTime*0.5+3.0)*(0.15+detach3*0.2), cos(uTime*0.55+2.5)*(0.12+detach3*0.18))*spreadBoost*fragAmplitude*reach3 + fragWobble + frag3Parallax;
    fragmentField += metaball(uv, fragPos3, 0.018*sizeBoost, 3.0);

    float drift4 = sin(uTime*0.12)*0.5+0.5+voiceInfluence*0.15;
    float2 fragPos4 = float2(cos(uTime*0.2+4.0)*(0.25+drift4*0.12), sin(uTime*0.18+3.5)*(0.2+drift4*0.1))*spreadBoost*fragAmplitude + fragWobble + frag4Parallax;
    fragmentField += metaball(uv, fragPos4, 0.02*sizeBoost, 2.6);

    float split5 = smoothstep(0.2, 0.6, sin(uTime*0.22+0.5)) + voiceInfluence*0.25;
    float2 fragPos5 = pos1 + float2(sin(uTime*0.35)*0.1*(1.0+split5*breakawayStrength*1.5), cos(uTime*0.28)*0.08*(1.0+split5*breakawayStrength*1.5))*fragAmplitude + fragWobble + frag5Parallax;
    fragmentField += metaball(uv, fragPos5, 0.024*(0.7+split5*0.5)*sizeBoost, 2.4);

    float wanderAmplitude6 = 1.0 + voiceInfluence*0.3;
    float2 fragPos6 = float2(sin(uTime*0.42+5.0)*cos(uTime*0.15)*0.28, cos(uTime*0.38+4.5)*sin(uTime*0.2)*0.22)*spreadBoost*fragAmplitude*wanderAmplitude6 + fragWobble + frag6Parallax;
    fragmentField += metaball(uv, fragPos6, 0.016*sizeBoost, 3.2);

    float hover7 = sin(uTime*0.8)*0.03 + voiceInfluence*0.03;
    float2 fragPos7 = float2(cos(uTime*0.1+6.0)*(0.32+hover7), sin(uTime*0.12+5.5)*(0.28+hover7))*spreadBoost*fragAmplitude + fragWobble + frag7Parallax;
    fragmentField += metaball(uv, fragPos7, 0.015*sizeBoost, 3.5);

    // Combine fields
    float thresholdWobble = noise(uv*4.0+uTime*1.5)*voiceInfluence*0.03;
    float cellThreshold = 0.42 + thresholdWobble;
    float mainCells = smoothstep(cellThreshold-0.12, cellThreshold+0.08, cellField);
    float fragThreshold = 0.35 + thresholdWobble*0.5;
    float fragments = smoothstep(fragThreshold-0.08, fragThreshold+0.06, fragmentField);
    float combined = cellField + fragmentField*0.7;
    float cells = smoothstep(cellThreshold-0.15, cellThreshold+0.1, combined);
    float isolatedFrags = fragments * (1.0 - smoothstep(0.3, 0.5, cellField));
    cells = max(cells, isolatedFrags * 0.85);

    float membrane = fbm2(uv*8.0+uTime*0.2);
    float membraneIntensity = 0.15 + voiceInfluence*0.05;
    cells *= 0.85 + membrane*membraneIntensity;

    float fragShimmer = sin(uTime*3.0+length(uv)*10.0)*0.1+0.9;
    cells += isolatedFrags*(0.15+voiceInfluence*0.05)*fragShimmer;
    cells *= glowBoost;

    // Core
    float coreDriftAmount = 0.05*(1.0-uIsRecording*0.7)*(1.0-thinkingFactor*0.6)*coreStability;
    float2 coreWobble = float2(noise(float2(uTime*5.0,0.0)), noise(float2(uTime*5.0,50.0)))*voiceInfluence*0.02;
    float2 corePos = float2(
        sin(uTime*0.12)*coreDriftAmount + cos(uTime*0.17)*coreDriftAmount*0.4 + sin(uTime*0.25)*0.03*thinkingFactor,
        cos(uTime*0.14)*coreDriftAmount + sin(uTime*0.09)*coreDriftAmount*0.5 + sin(uTime*0.35)*cos(uTime*0.2)*0.02*thinkingFactor
    ) + coreWobble + coreParallax + curiousOffset + contentmentSway + listeningFocus;

    float coreDist = length(uv - corePos);
    float basePulseSpeed = 1.8 + transcribingFactor*0.8 - thinkingFactor*0.4;
    float pulseDepth = 0.12 + voiceInfluence*0.08;
    float corePulse = 1.0 + sin(uTime*basePulseSpeed)*pulseDepth + noise(float2(uTime*2.5,0.0))*voiceInfluence*0.04 + heartbeatPulse + sin(uTime*1.2)*0.08*thinkingFactor + computeIntensity*0.3;
    float coreSize = 0.07*corePulse*(1.0+uIsRecording*0.15+voiceInfluence*0.1)*(1.0+thinkingFactor*0.3)*(1.0+completeFactor*0.15);

    float coreInner = smoothstep(coreSize*0.5, coreSize*0.15, coreDist);
    float coronaBrightness = 1.0 + noise(float2(uTime*3.0,25.0))*voiceInfluence*0.12;
    float coreCorona = smoothstep(coreSize*1.4, coreSize*0.4, coreDist)*0.6*coronaBrightness;
    float coreGlow = pow(smoothstep(coreSize*2.5, coreSize*0.6, coreDist), 2.0)*0.35*(1.0+voiceInfluence*0.2);
    float coreEffect = (coreInner + coreCorona + coreGlow)*(1.0+uIsRecording*0.15+voiceInfluence*0.08);

    // Ring
    float idleBreathFactorR = 1.0 - uIntensity;
    float breathe = sin(uTime*1.5)*0.015*idleBreathFactorR;
    float ringScale = 1.0 - thinkingFactor*0.03 + completeFactor*0.02;
    float ringVoicePulse = voiceInfluence*0.015*sin(uTime*3.0);
    float baseRadius = (0.52+breathe+uIsRecording*0.03+smoothIntensity*0.03+ringVoicePulse)*ringScale;
    float thickness = 0.022 + voiceInfluence*0.004;
    float distortionAmount = 0.012+voiceInfluence*0.01;
    float noiseA = circularNoise4(ringAngle, 2.0, time*0.4);
    float distort = noiseA*distortionAmount;
    float ring1Radius = baseRadius+distort;
    float mainRing = smoothstep(thickness*1.5, thickness*0.1, abs(ringRadius-ring1Radius))*0.5;

    float gradientAngle = (ringAngle+PI)/(2.0*PI);
    float ringGradient = 0.15+gradientAngle*0.1;

    float segmentCount = 3.0;
    float rotatingAngle = angle+transcribeRotation;
    float segmentsVal = smoothstep(0.4, 0.6, fract(rotatingAngle/(2.0*PI)*segmentCount));
    float segmentedRing = mainRing*mix(1.0, 0.6+segmentsVal*0.4, transcribingFactor);
    float pulsingThickness = thickness*(1.0+transcribePulse*0.3);
    float pulsingRing = smoothstep(pulsingThickness*1.5, pulsingThickness*0.1, abs(radius-ring1Radius))*0.5;
    segmentedRing = mix(segmentedRing, pulsingRing, transcribingFactor*0.5);

    float glowDist = abs(radius-ring1Radius);
    float glow1 = pow(smoothstep(0.08, 0.0, glowDist), 1.5)*0.2;
    float glow2 = pow(smoothstep(0.15, 0.0, glowDist), 2.0)*0.1;

    float totalAlpha = segmentedRing*0.6 + glow1 + glow2;
    totalAlpha *= 1.0+uIntensity*0.5;

    float innerRadiusVal = ring1Radius - thickness*2.0;
    float centerMask = smoothstep(innerRadiusVal+0.05, innerRadiusVal-0.2, radius);
    float cellGlowVal = cells*0.6;
    float cellEdgeGlow = smoothstep(cellThreshold-0.05, cellThreshold+0.05, cellField)*0.3;
    float centerFill = centerMask*(0.3+cellGlowVal+cellEdgeGlow)*(0.6+uIntensity*0.25);
    totalAlpha += centerFill;
    totalAlpha += coreEffect*centerMask;
    totalAlpha += innerGlow*centerMask;

    // Color
    float3 darkColor = float3(0.039);
    float3 midColor = float3(0.541, 0.525, 0.502);
    float3 lightColor = float3(0.961, 0.953, 0.941);
    float3 recordingTint = float3(0.98, 0.97, 0.95)*uIsRecording + float3(1.0)*(1.0-uIsRecording);

    float grayscale = 0.25 + (1.0-radius)*0.25;
    grayscale -= segmentedRing*(0.15-ringGradient*0.08);
    grayscale += (glow1+glow2)*0.12;
    grayscale += cells*0.3 + cellEdgeGlow*0.15;
    float coreBoostVal = 0.6+thinkingFactor*0.15+completeFactor*0.1;
    grayscale += coreEffect*coreBoostVal + coreInner*0.45;
    grayscale += innerGlow*0.6;
    grayscale += uIntensity*0.1;
    grayscale *= completeBrightness;
    grayscale += transcribePulse*0.05;
    grayscale += rippleWave*rippleIntensity*centerMask;
    grayscale += computeIntensity*centerMask;
    grayscale += burstBrightnessVal*centerMask;
    grayscale += directionalGlow;

    float vignette = smoothstep(0.6, 0.2, radius);
    grayscale *= 0.7+vignette*0.3;

    // Rim lighting
    float2 lightDir = normalize(uTilt + float2(0.001));
    float tiltMagnitude = length(uTilt);
    float rimRadius2 = smoothstep(0.35, 0.55, radius);
    float rimFalloff = smoothstep(0.65, 0.52, radius);
    float rimMask = rimRadius2*rimFalloff;
    float pixelAngle = atan2(uv.y, uv.x);
    float lightAngle2 = atan2(lightDir.y, lightDir.x);
    float rimAlignment = pow(cos(pixelAngle-lightAngle2)*0.5+0.5, 2.0);
    grayscale += rimMask*rimAlignment*tiltMagnitude*1.2*0.4 + rimMask*0.08;

    grayscale = clamp(grayscale, 0.0, 1.0);

    float3 color;
    if (grayscale < 0.5) {
        color = mix(darkColor, midColor, grayscale*2.0);
    } else {
        color = mix(midColor, lightColor, (grayscale-0.5)*2.0);
    }
    color *= recordingTint;
    color *= 0.92+0.08*sin(angle*2.0+uTime*0.5);
    color *= 1.0+sin(uTime*1.5)*0.025*idleBreathFactorR;

    totalAlpha = clamp(totalAlpha, 0.0, 1.0);
    return half4(half3(color*totalAlpha), half(totalAlpha));
}
