import React, { useRef, useEffect } from 'react';
import { Canvas } from '@react-three/fiber';
import { useGLTF, OrbitControls, Stars, Sky, Camera, spotLight } from '@react-three/drei';
import { useFrame } from '@react-three/fiber';
import './styles.css';

// ------------------------------------------------------------------
// Global input store (simple)
// ------------------------------------------------------------------
const keyState = {
  forward: false,
  back: false,
  left: false,
  right: false,
  nitro: false,
};

useEffect(() => {
  const down = (e: KeyboardEvent) => {
    if (e.code === 'KeyW' || e.code === 'ArrowUp') keyState.forward = true;
    if (e.code === 'KeyS' || e.code === 'ArrowDown') keyState.back = true;
    if (e.code === 'KeyA' || e.code === 'ArrowLeft') keyState.left = true;
    if (e.code === 'KeyD' || e.code === 'ArrowRight') keyState.right = true;
    if (e.code === 'Space') keyState.nitro = true;
  };
  const up = (e: KeyboardEvent) => {
    if (e.code === 'KeyW' || e.code === 'ArrowUp') keyState.forward = false;
    if (e.code === 'KeyS' || e.code === 'ArrowDown') keyState.back = false;
    if (e.code === 'KeyA' || e.code === 'ArrowLeft') keyState.left = false;
    if (e.code === 'KeyD' || e.code === 'ArrowRight') keyState.right = false;
    if (e.code === 'Space') keyState.nitro = false;
  };
  window.addEventListener('keydown', down);
  window.addEventListener('keyup', up);
  return () => {
    window.removeEventListener('keydown', down);
    window.removeEventListener('keyup', up);
  };
}, []);

// Touch steering (left/right half)
useEffect(() => {
  let touchX = 0;
  const start = (e: TouchEvent) => {
    if (e.touches.length === 1) touchX = e.touches[0].clientX;
  };
  const move = (e: TouchEvent) => {
    if (e.touches.length === 1) {
      const dx = e.touches[0].clientX - touchX;
      keyState.left = dx < -10; // arbitrary threshold
      keyState.right = dx > 10;
      touchX = e.touches[0].clientX;
    }
  };
  const end = () => { keyState.left = keyState.right = false; };
  window.addEventListener('touchstart', start, { passive: true });
  window.addEventListener('touchmove', move, { passive: false });
  window.addEventListener('touchend', end);
  window.addEventListener('touchcancel', end);
  return () => {
    window.removeEventListener('touchstart', start);
    window.removeEventListener('touchmove', move);
    window.removeEventListener('touchend', end);
    window.removeEventListener('touchcancel', end);
  };
}, []);

// ------------------------------------------------------------------
// Vehicle state
// ------------------------------------------------------------------
type VehicleState = {
  position: [number, number, number];
  rotationY: number;
  speed: number;
  steer: number;
  nitro: number;
};

const useVehicle = () => {
  const stateRef = useRef<VehicleState>({
    position: [0, 0.5, 0],
    rotationY: 0,
    speed: 0,
    steer: 0,
    nitro: 1,
  });

  return stateRef;
};

// ------------------------------------------------------------------
// Car component with physics
// ------------------------------------------------------------------
function Car() {
  const { nodes, materials } = useGLTF('/models/car.glb');
  const vehicle = useVehicle();

  // physics constants
  const GRAVITY = -9.81;
  const GROUND_Y = 0.5;
  const MAX_SPEED = 30; // m/s ~108 km/h
  const ACCEL = 20;
  const BRAKE = 30;
  const STEER_SPEED = 2.5;
  const STEER_RETURN = 4;
  const NITRO_BOOST = 15;
  const NITRO_DRAIN = 0.5;
  const NITRO_REFILL = 0.2;

  useFrame((state, delta) => {
    const s = vehicle.current;

    // INPUT
    const accel = keyState.forward ? 1 : keyState.back ? -1 : 0;
    const steerInput = keyState.right ? 1 : keyState.left ? -1 : 0;
    const nitroOn = keyState.nitro && s.nitro > 0;

    // THrottle / brake
    const accelForce = accel * ACCEL * (nitroOn ? 2.5 : 1);
    const brakeForce = (accel === 0 && !keyState.forward && !keyState.back) ? 0 : (keyState.back ? BRAKE : 0);
    // Apply acceleration/braking
    s.speed += (accelForce - brakeForce) * delta;
    // Clamp speed
    const maxSpeed = nitroOn ? MAX_SPEED + NITRO_BOOST : MAX_SPEED;
    if (s.speed > maxSpeed) s.speed = maxSpeed;
    if (s.speed < -5) s.speed = -5; // reverse limit

    // Steering (speed dependent)
    const steerScale = Math.max(0.2, 1 - Math.abs(s.speed) / maxSpeed);
    s.steer += steerInput * STEER_SPEED * steerScale * delta;
    // Clamp steer
    if (s.steer > 1) s.steer = 1;
    if (s.steer < -1) s.steer = -1;
    // Return to centre
    if (steerInput === 0) {
      if (s.steer > 0) s.steer -= STEER_RETURN * delta;
      else if (s.steer < 0) s.steer += STEER_RETURN * delta;
      if (Math.abs(s.steer) < 0.01) s.steer = 0;
    }

    // Nitro
    if (nitroOn) {
      s.nitro -= NITRO_DRAIN * delta;
      if (s.nitro < 0) s.nitro = 0;
    } else {
      s.nitro += NITRO_REFILL * delta;
      if (s.nitro > 1) s.nitro = 1;
    }

    // Apply movement
    const rad = s.rotationY;
    const dx = Math.sin(rad) * s.speed * delta;
    const dz = Math.cos(rad) * s.speed * delta;
    s.position[0] += dx;
    s.position[2] -= dz; // Note: three.js uses -z forward? we used earlier -z; keep consistent

    // Gravity / ground
    s.position[1] += GRAVITY * delta;
    if (s.position[1] < GROUND_Y) {
      s.position[1] = GROUND_Y;
      // optional: zero vertical velocity
    }

    // Update rotation (yaw)
    s.rotationY += s.steer * (s.speed / maxSpeed) * 0.5 * delta; // simple steering influence
  });

  // Render
  return (
    <group
      position={vehicle.current.position}
      rotation={[0, vehicle.current.rotationY, 0]}
    >
      <primitive object={nodes} />
    </group>
  );
}

// ------------------------------------------------------------------
// Road component
// ------------------------------------------------------------------
function Road() {
  const { nodes, materials } = useGLTF('/models/road.glb');
  return <primitive object={nodes} />;
}

// ------------------------------------------------------------------
// Scene
// ------------------------------------------------------------------
function Scene() {
  return (
    <>
      <ambientLight intensity={0.5} />
      <directionalLight position={[10, 20, 10]} intensity={1.5} castShadow />
      <spotLight position={[0, 30, 20]} angle={0.3} penumbra={1} intensity={2.5} castShadow />
      <Suspense fallback={null}>
        <Road />
        <Car />
      </Suspense>
    </>
  );
}

// ------------------------------------------------------------------
// App
// ------------------------------------------------------------------
function App() {
  return (
    <>
      <Camera position={[0, 5, 15]} makeDefault>
        <OrbitControls enableZoom={true} />
      </Camera>
      <Sky />
      <Canvas shadows camera={{ position: [0, 5, 15], fov: 60 }} gl={{ antialias: true }}>
        <Scene />
      </Canvas>
    </>
  );
}

// ------------------------------------------------------------------
// Render
// ------------------------------------------------------------------
import { createRoot } from 'react-dom/client';
const root = createRoot(document.getElementById('root')!);
root.render(<App />);
