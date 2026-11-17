import { router, promptAction } from '@kit.ArkUI';
import { Rule, SensorKey, DeviceKey, sensorUnit } from '../model/Models';
import { CabinStore } from '../storage/CabinStore';
import { CabinEngine } from '../engine/CabinEngine';

interface EditorParams { id: string; }
@Entry
@Component
struct RuleEditor {
  @State name: string = '';
  @State sensorIndex: number = 0;
  @State compareIndex: number = 0;
  @State threshold: string = '30';
  @State deviceIndex: number = 0;
  @State actionIndex: number = 0;
  @State priority: string = '10';
  @State error: string = '';
  @State busy: boolean = false;
  private editingId: string = '';
  private ruleEnabled: boolean = true;
  private sensors: SensorKey[] = ['temperature', 'humidity', 'light'];
  private devices: DeviceKey[] = ['fan', 'pump', 'lamp'];

  aboutToAppear(): void {
    const p = router.getParams() as EditorParams;
    this.editingId = p ? p.id : '';
    const r = CabinStore.engine.state.rules.find((v: Rule) => v.id === this.editingId);
    if (r) {
      this.name = r.name; this.sensorIndex = this.sensors.indexOf(r.sensor); this.threshold = r.threshold.toString();
      this.compareIndex = r.compare === 'above' ? 0 : 1; this.deviceIndex = this.devices.indexOf(r.device);
      this.actionIndex = r.action ? 0 : 1; this.priority = r.priority.toString(); this.ruleEnabled = r.enabled;
    }
  }
  async save(): Promise<void> {
    if (this.threshold.trim() === '' || this.priority.trim() === '') { this.error = '请填写阈值和优先级'; return; }
    const r = new Rule(); r.id = this.editingId; r.name = this.name; r.sensor = this.sensors[this.sensorIndex];
    r.compare = this.compareIndex === 0 ? 'above' : 'below'; r.threshold = Number(this.threshold);
    r.device = this.devices[this.deviceIndex]; r.action = this.actionIndex === 0; r.priority = Number(this.priority); r.enabled = this.ruleEnabled;
    this.error = CabinEngine.validateRule(r); if (this.error) { return; }
    // 写入失败时回滚内存，留在页面供用户重试，避免新增规则重复。
    const before = JSON.stringify(CabinStore.engine.state);
    this.error = CabinStore.engine.saveRule(r, new Date().toLocaleTimeString());
    if (this.error) { return; }
    this.busy = true;
    const ok = await CabinStore.save(); this.busy = false;
    if (ok) { promptAction.showToast({ message: '规则已保存' }); router.back(); }
    else { CabinStore.engine = new CabinEngine(JSON.parse(before)); this.error = '保存失败，请重试'; }
  }
  @Builder
  label(text: string) { Text(text).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#32503B').width('100%').margin({ top: 12, bottom: 8 }) }
  build() {
    Column() {
      Row() {
        Text('‹ 返回').fontSize(15).fontColor('#267553').onClick(() => { router.back(); })
        Blank()
        Text(this.editingId ? '编辑规则' : '新建规则').fontSize(19).fontWeight(FontWeight.Bold).fontColor('#183E32')
      }.width('100%').padding(20)
      Scroll() {
        Column() {
          Text('当环境满足条件\n让设备自动行动').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#174A3A').lineHeight(36).width('100%')
          this.label('规则名称')
          TextInput({ placeholder: '例如 午后高温通风', text: this.name }).height(46).backgroundColor('#FFFFFF').maxLength(20)
            .onChange((v: string) => { this.name = v; })
          this.label('监测指标')
          Select([{ value: '空气温度 °C' }, { value: '空气湿度 %' }, { value: '环境光照 lx' }]).selected(this.sensorIndex)
            .value(['空气温度 °C', '空气湿度 %', '环境光照 lx'][this.sensorIndex]).width('100%').backgroundColor('#FFFFFF')
            .onSelect((i: number) => { this.sensorIndex = i; })
          this.label('触发条件')
          Row({ space: 10 }) {
            Select([{ value: '大于 >' }, { value: '小于 <' }]).selected(this.compareIndex).value(this.compareIndex === 0 ? '大于 >' : '小于 <')
              .width('43%').backgroundColor('#FFFFFF').onSelect((i: number) => { this.compareIndex = i; })
            TextInput({ text: this.threshold, placeholder: '阈值' }).layoutWeight(1).height(46).backgroundColor('#FFFFFF')
              .onChange((v: string) => { this.threshold = v; })
          }.width('100%')
          Text('范围 ' + CabinEngine.range(this.sensors[this.sensorIndex]).join(' ～ ') + ' ' + sensorUnit(this.sensors[this.sensorIndex]) + '；等于阈值时不触发。')
            .fontSize(11).fontColor('#818B74').width('100%').margin({ top: 7 })
          this.label('执行设备')
          Select([{ value: '通风扇' }, { value: '灌溉泵' }, { value: '补光灯' }]).selected(this.deviceIndex)
            .value(['通风扇', '灌溉泵', '补光灯'][this.deviceIndex]).width('100%').backgroundColor('#FFFFFF')
            .onSelect((i: number) => { this.deviceIndex = i; })
          this.label('执行动作')
          Select([{ value: '开启设备' }, { value: '关闭设备' }]).selected(this.actionIndex).value(this.actionIndex === 0 ? '开启设备' : '关闭设备')
            .width('100%').backgroundColor('#FFFFFF').onSelect((i: number) => { this.actionIndex = i; })
          this.label('优先级')
          TextInput({ text: this.priority, placeholder: '1～99，数字越大优先级越高' }).height(46).backgroundColor('#FFFFFF')
            .onChange((v: string) => { this.priority = v; })
          Text('同一设备多个条件同时命中时，仅执行优先级最高的规则。手动接管和设备离线时不执行自动动作。')
            .fontSize(12).fontColor('#7A866E').lineHeight(20).width('100%').margin({ top: 15 })
          if (this.error !== '') { Text(this.error).fontSize(13).fontColor('#AF553B').width('100%').margin({ top: 14 }) }
          Button(this.busy ? '保存中…' : '保存规则').width('100%').height(48).backgroundColor('#267553').enabled(!this.busy)
            .margin({ top: 20, bottom: 30 }).onClick(() => { this.save(); })
        }.width('100%').padding({ left: 22, right: 22 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F4F6F0')
  }
}

