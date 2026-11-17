import { common } from '@kit.AbilityKit';
import { router, promptAction } from '@kit.ArkUI';
import { CabinStore } from '../storage/CabinStore';
import { CabinState, Device, EventLog, Rule, Sample, SensorKey, sensorName, sensorUnit, deviceName } from '../model/Models';
import { CabinEngine } from '../engine/CabinEngine';
import { MetricTile } from '../components/MetricTile';

@Entry
@Component
struct Index {
  @State data: CabinState = CabinEngine.initial();
  @State status: string = '正在读取本地数据…';
  @State ready: boolean = false;
  @State selectedTab: number = 0;
  @State logFilter: string = '全部';
  @State saving: boolean = false;

  aboutToAppear(): void { this.load(); }
  onPageShow(): void { if (CabinStore.ready) { this.refresh(); } }
  async load(): Promise<void> {
    await CabinStore.load(getContext(this) as common.UIAbilityContext);
    this.ready = CabinStore.ready; this.refresh();
  }
  refresh(): void {
    this.data = JSON.parse(JSON.stringify(CabinStore.engine.state)) as CabinState;
    this.status = CabinStore.status;
  }
  now(): string { return new Date().toLocaleTimeString(); }
  toast(s: string): void { promptAction.showToast({ message: s }); }
  async changed(): Promise<void> {
    this.refresh(); this.saving = true;
    const ok = await CabinStore.save();
    this.saving = false; this.refresh();
    if (!ok) { this.toast(CabinStore.status); }
  }
  update(key: SensorKey, value: number, mode: SliderChangeMode): void {
    const error = CabinStore.engine.setEnvironment(key, Math.round(value * 10) / 10, this.now());
    if (error) { this.toast(error); return; }
    this.refresh();
    if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) { this.changed(); }
  }
  scene(kind: string): void {
    const e = CabinStore.engine;
    if (kind === '高温干燥') {
      e.setEnvironment('temperature', 36, this.now()); e.setEnvironment('humidity', 28, this.now()); e.setEnvironment('light', 650, this.now());
    } else if (kind === '夜间弱光') {
      e.setEnvironment('temperature', 24, this.now()); e.setEnvironment('humidity', 58, this.now()); e.setEnvironment('light', 80, this.now());
    } else {
      e.setEnvironment('temperature', 26, this.now()); e.setEnvironment('humidity', 60, this.now()); e.setEnvironment('light', 500, this.now());
    }
    e.log('场景', '载入' + kind, this.now()); this.changed();
  }
  @Builder
  title(label: string, note: string) {
    Row() {
      Text(label).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#183E32').layoutWeight(1)
      Text(note).fontSize(11).fontColor('#788375')
    }.width('100%').margin({ top: 22, bottom: 12 })
  }
  @Builder
  slider(label: string, key: SensorKey, value: number, min: number, max: number) {
    Column({ space: 3 }) {
      Row() {
        Text(label).fontSize(13).fontColor('#41574A').layoutWeight(1)
        Text(value.toFixed(key === 'light' ? 0 : 1) + ' ' + sensorUnit(key)).fontSize(13).fontColor('#174A3A')
      }.width('100%')
      Slider({ value: value, min: min, max: max, step: key === 'light' ? 10 : 1 })
        .selectedColor('#267553').trackColor('#DFE7DC').blockColor('#174A3A')
        .onChange((v: number, mode: SliderChangeMode) => { this.update(key, v, mode); })
    }.width('100%')
  }
  @Builder
  deviceCard(d: Device) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(d.id === 'fan' ? '风' : d.id === 'pump' ? '水' : '光').fontSize(18).fontWeight(FontWeight.Bold)
          .fontColor(d.on ? '#FFFFFF' : '#2A654A').width(40).height(40).textAlign(TextAlign.Center)
          .backgroundColor(d.on ? '#267553' : '#E9F0E4').borderRadius(13)
        Column({ space: 3 }) {
          Text(d.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#183E32')
          Text(!d.online ? '离线' : d.manual ? '手动接管' : '自动模式').fontSize(11).fontColor(d.manual ? '#A66E24' : '#73816E')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: d.on }).selectedColor('#267553').enabled(d.online)
          .onChange((on: boolean) => {
            // 忽略由规则驱动的组件同步，只有不同值才代表用户操作。
            if (on === d.on) { return; }
            const error = CabinStore.engine.control(d.id, on, this.now());
            if (error) { this.toast(error); } else { this.changed(); }
          })
      }.width('100%')
      Text(d.reason).fontSize(11).fontColor('#73816E').width('100%')
      Row({ space: 12 }) {
        if (d.manual) {
          Button('交还自动').fontSize(11).height(28).backgroundColor('#E9F0E4').fontColor('#174A3A')
            .onClick(() => { CabinStore.engine.release(d.id, this.now()); this.changed(); })
        }
        Blank()
        Text(d.online ? '模拟离线' : '恢复在线').fontSize(11).fontColor('#867256')
          .onClick(() => { CabinStore.engine.setOnline(d.id, !d.online, this.now()); this.changed(); })
      }.width('100%')
    }.padding(16).width('100%').backgroundColor('#FFFFFF').borderRadius(18).margin({ bottom: 10 })
  }
  @Builder
  overview() {
    Scroll() {
      Column() {
        Column({ space: 10 }) {
          Row() {
            Text('GREENHOUSE / 01').fontSize(10).fontColor('#CCE0BF').letterSpacing(2).layoutWeight(1)
            Text('本地仿真').fontSize(10).fontColor('#E5F1D7').padding({ left: 9, right: 9, top: 5, bottom: 5 })
              .borderRadius(12).backgroundColor('#32604B')
          }.width('100%')
          Text('让每一份生长\n都有恰好的照料').fontSize(25).fontWeight(FontWeight.Medium).fontColor('#F3F7E9')
            .lineHeight(34).width('100%')
          Row() {
            Text(this.data.automation ? '自动联动运行中' : '自动联动已暂停').fontSize(12).fontColor('#D7E8C9').layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.data.automation }).selectedColor('#8FBC75')
              .onChange((on: boolean) => {
                if (on !== this.data.automation) { CabinStore.engine.setAutomation(on, this.now()); this.changed(); }
              })
          }.width('100%')
        }.width('100%').padding(20).backgroundColor('#174A3A').borderRadius(22)
        this.title('环境概览', '第 ' + this.data.tick + ' 次采样')
        Row({ space: 8 }) {
          MetricTile({ label: '空气温度', value: this.data.environment.temperature.toFixed(1), unit: '°C', note: '参考 20～30 °C' })
          MetricTile({ label: '空气湿度', value: this.data.environment.humidity.toFixed(0), unit: '%', note: '参考 40～70 %' })
          MetricTile({ label: '环境光照', value: this.data.environment.light.toFixed(0), unit: 'lx', note: '参考 300～800 lx' })
        }.width('100%')
        this.title('环境实验台', '拖动数值观察联动')
        Column({ space: 10 }) {
          this.slider('温度', 'temperature', this.data.environment.temperature, -10, 60)
          this.slider('湿度', 'humidity', this.data.environment.humidity, 0, 100)
          this.slider('光照', 'light', this.data.environment.light, 0, 2000)
          Row({ space: 6 }) {
            ForEach(['高温干燥', '夜间弱光', '舒适环境'], (s: string) => {
              Button(s).fontSize(11).height(34).layoutWeight(1).fontColor('#315640').backgroundColor('#EDF2E6')
                .onClick(() => { this.scene(s); })
            })
          }.width('100%')
          Button('推进一次仿真 →').width('100%').height(42).fontSize(14).fontColor('#FFFFFF').backgroundColor('#267553')
            .onClick(() => { CabinStore.engine.step(this.now()); this.changed(); })
          Text('每次推进由当前设备状态计算环境变化；无后台定时任务。').fontSize(10).fontColor('#808979')
        }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(18)
        this.title('设备控制', '手动控制可交还自动')
        ForEach(this.data.devices, (d: Device) => { this.deviceCard(d) }, (d: Device) => JSON.stringify(d))
        if (this.data.samples.length > 0) {
          this.title('最近采样', '温度趋势 / °C')
          Row({ space: 5 }) {
            ForEach(this.data.samples, (s: Sample) => {
              Column({ space: 4 }) {
                Text(s.temperature.toFixed(0)).fontSize(9).fontColor('#46644E')
                Rect().width('80%').height(Math.max(4, (s.temperature + 10) * 1.1)).fill('#7AA36D').radius(3)
                Text(s.tick.toString()).fontSize(9).fontColor('#85907B')
              }.layoutWeight(1).justifyContent(FlexAlign.End).height(110)
            }, (s: Sample) => s.tick.toString())
          }.width('100%').padding(12).backgroundColor('#FFFFFF').borderRadius(18)
        }
        Text(this.status).fontSize(10).fontColor('#7C8776').margin({ top: 18, bottom: 20 })
      }.width('100%').padding({ left: 18, right: 18, top: 8, bottom: 12 })
    }.scrollBar(BarState.Off).layoutWeight(1).width('100%')
  }
  @Builder
  rules() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 6 }) {
            Text('把照料写成规则').fontSize(23).fontWeight(FontWeight.Bold).fontColor('#183E32')
            Text(this.data.rules.length + ' / 20 条规则').fontSize(12).fontColor('#74816F')
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('＋ 新建').fontSize(13).height(36).backgroundColor('#267553')
            .onClick(() => { router.pushUrl({ url: 'pages/RuleEditor', params: { id: '' } }); })
        }.width('100%').margin({ top: 16, bottom: 6 })
        Text('仅执行满足条件的规则。优先级数字越大越先执行；同优先级按规则 ID 排序。无命中时关闭自动设备。')
          .fontSize(12).fontColor('#6F7F68').lineHeight(19).width('100%')
        if (this.data.rules.length === 0) { Text('还没有规则，点击右上角新建。').fontSize(14).fontColor('#71806A').margin(30) }
        ForEach(this.data.rules, (r: Rule) => {
          Column({ space: 12 }) {
            Row() {
              Text(r.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#183E32').layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: r.enabled }).selectedColor('#267553')
                .onChange((on: boolean) => { if (on !== r.enabled) { CabinStore.engine.toggleRule(r.id, this.now()); this.changed(); } })
            }.width('100%')
            Text('当 ' + sensorName(r.sensor) + (r.compare === 'above' ? ' > ' : ' < ') + r.threshold + ' ' + sensorUnit(r.sensor))
              .fontSize(15).fontColor('#46654D').width('100%')
            Text('则 ' + (r.action ? '开启' : '关闭') + deviceName(r.device)).fontSize(15).fontColor('#46654D').width('100%')
            Row({ space: 16 }) {
              Text('优先级 ' + r.priority).fontSize(11).fontColor('#8B956F').layoutWeight(1)
              Text('编辑').fontSize(13).fontColor('#267553').onClick(() => {
                router.pushUrl({ url: 'pages/RuleEditor', params: { id: r.id } });
              })
              Text('删除').fontSize(13).fontColor('#A36D51').onClick(() => {
                AlertDialog.show({ title: '删除规则', message: '确定删除“' + r.name + '”？',
                  primaryButton: { value: '取消', action: () => {} },
                  secondaryButton: { value: '删除', action: () => { CabinStore.engine.removeRule(r.id, this.now()); this.changed(); } } });
              })
            }.width('100%')
          }.width('100%').padding(18).backgroundColor('#FFFFFF').borderRadius(18)
        }, (r: Rule) => JSON.stringify(r))
      }.width('100%').padding({ left: 18, right: 18, bottom: 30 })
    }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
  }
  @Builder
  logs() {
    Column({ space: 12 }) {
      Row() {
        Text('每一次变化都有迹可循').fontSize(21).fontWeight(FontWeight.Bold).fontColor('#183E32').layoutWeight(1)
        Text(this.data.logs.length + '/100').fontSize(12).fontColor('#7F896F')
      }.width('100%').margin({ top: 18 })
      Row({ space: 8 }) {
        ForEach(['全部', '联动', '手动', '规则', '设备'], (v: string) => {
          Button(v).fontSize(11).height(30).layoutWeight(1)
            .backgroundColor(this.logFilter === v ? '#267553' : '#E7EDDF').fontColor(this.logFilter === v ? '#FFFFFF' : '#546B4C')
            .onClick(() => { this.logFilter = v; })
        })
      }.width('100%')
      Text('仅保留最近 100 条；重复计算但状态未变时不重复记联动日志。').fontSize(11).fontColor('#7D8972').width('100%')
      List({ space: 10 }) {
        ForEach(this.data.logs.filter((l: EventLog) => this.logFilter === '全部' || l.kind === this.logFilter), (l: EventLog) => {
          ListItem() {
            Column({ space: 8 }) {
              Row() {
                Text(l.kind).fontSize(11).fontColor('#267553').layoutWeight(1)
                Text(l.time).fontSize(10).fontColor('#8A927F')
              }.width('100%')
              Text(l.message).fontSize(13).fontColor('#3F5745').lineHeight(20).width('100%')
            }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(16)
          }
        }, (l: EventLog) => l.id.toString())
        if (this.data.logs.length === 0) { ListItem() { Text('操作设备或载入场景后，记录会显示在这里。').fontSize(13).fontColor('#7F896F').margin({ top: 30 }) } }
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
      Text(this.status).fontSize(10).fontColor('#7D8972').margin({ bottom: 12 })
    }.width('100%').layoutWeight(1).padding({ left: 18, right: 18 })
  }
  build() {
    Column() {
      Row() {
        Column({ space: 2 }) {
          Text('青禾智舱').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#173F32')
          Text('QINGHE CABIN').fontSize(9).letterSpacing(2).fontColor('#7B886F')
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Text(this.saving ? '保存中' : '规则温室').fontSize(11).fontColor('#66785B')
      }.width('100%').padding({ left: 22, right: 22, top: 15, bottom: 15 })
      if (!this.ready) {
        Column({ space: 16 }) {
          Text(this.status).fontSize(14).fontColor('#6F7F68')
          Button('重新加载').backgroundColor('#267553').onClick(() => { this.load(); })
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        if (this.selectedTab === 0) { this.overview() }
        else if (this.selectedTab === 1) { this.rules() }
        else { this.logs() }
      }
      Row() {
        ForEach(['温室', '规则', '日志'], (v: string, i: number) => {
          Column({ space: 5 }) {
            Text(i === 0 ? '⌂' : i === 1 ? '☷' : '≡').fontSize(22).fontColor(this.selectedTab === i ? '#267553' : '#9BA48D')
            Text(v).fontSize(11).fontWeight(this.selectedTab === i ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedTab === i ? '#267553' : '#87937B')
          }.layoutWeight(1).padding({ top: 10, bottom: 10 }).onClick(() => { this.selectedTab = i; })
        })
      }.width('100%').backgroundColor('#FFFFFF')
    }.width('100%').height('100%').backgroundColor('#F4F6F0')
  }
}
