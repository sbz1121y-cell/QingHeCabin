@Component
export struct SensorControl {
  @Prop label: string = '';
  @Prop value: number = 0;
  @Prop unit: string = '';
  @Prop minimum: number = 0;
  @Prop maximum: number = 100;
  @Prop stepSize: number = 1;
  @Prop decimals: number = 1;
  onValue: (value: number, mode: SliderChangeMode) => void = () => {};
  build() {
    Column({ space: 3 }) {
      Row() {
        Text(this.label).fontSize(13).fontColor('#41574A').layoutWeight(1)
        Text(this.value.toFixed(this.decimals) + ' ' + this.unit).fontSize(13).fontColor('#174A3A')
      }.width('100%')
      Slider({ value: this.value, min: this.minimum, max: this.maximum, step: this.stepSize })
        .selectedColor('#267553').trackColor('#DFE7DC').blockColor('#174A3A')
        .onChange((v: number, mode: SliderChangeMode) => { this.onValue(v, mode); })
    }.width('100%')
  }
}
