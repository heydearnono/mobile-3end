import m1UiTest from './M1Ui.test';
import m2m3DeviceTest from './M2M3Device.test';
import m4DeviceTest from './M4Device.test';

export default function testsuite() {
  // M4 放最前面：它用直达入口，只依赖已写好的离线包，不会被 M1–M3 的空卡住
  m4DeviceTest();
  m1UiTest();
  m2m3DeviceTest();
}
