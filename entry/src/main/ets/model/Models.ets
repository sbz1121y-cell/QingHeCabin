export type SensorKey = 'temperature' | 'humidity' | 'light';
export type DeviceKey = 'fan' | 'pump' | 'lamp';
export type Compare = 'above' | 'below';

export class Environment {
  temperature: number = 28;
  humidity: number = 55;
  light: number = 480;
}
export class Device {
  id: DeviceKey = 'fan';
  name: string = '';
  on: boolean = false;
  online: boolean = true;
  manual: boolean = false;
  reason: string = '等待规则计算';
  constructor(id: DeviceKey, name: string) { this.id = id; this.name = name; }
}
export class Rule {
  id: string = '';
  name: string = '';
  sensor: SensorKey = 'temperature';
  compare: Compare = 'above';
  threshold: number = 30;
  device: DeviceKey = 'fan';
  action: boolean = true;
  priority: number = 10;
  enabled: boolean = true;
}
export class EventLog {
  id: number = 0;
  time: string = '';
  kind: string = '';
  message: string = '';
}
export class Sample {
  tick: number = 0;
  temperature: number = 0;
  humidity: number = 0;
  light: number = 0;
}
export class CabinState {
  schemaVersion: number = 1;
  environment: Environment = new Environment();
  devices: Device[] = [];
  rules: Rule[] = [];
  logs: EventLog[] = [];
  samples: Sample[] = [];
  automation: boolean = true;
  tick: number = 0;
  sequence: number = 0;
  savedAt: string = '';
}
export function sensorName(key: SensorKey): string {
  if (key === 'temperature') { return '温度'; }
  if (key === 'humidity') { return '湿度'; }
  return '光照';
}
export function sensorUnit(key: SensorKey): string {
  if (key === 'temperature') { return '°C'; }
  if (key === 'humidity') { return '%'; }
  return 'lx';
}
export function deviceName(key: DeviceKey): string {
  if (key === 'fan') { return '通风扇'; }
  if (key === 'pump') { return '灌溉泵'; }
  return '补光灯';
}
