Ты продолжаешь работу над Godot-проектом ACORN HUNTER / Arkon.

Сначала прочитай:
res://HANDOFF_2026-10-07.md

НЕ начинай расследование с нуля. Используй handoff как recovery point.

Репозиторий:
masterofmagic234/Arkon
ветка:
fix/level2-final-game-flow
PR #11
Godot 4.7.2
Android / GL Compatibility

Перед любыми изменениями обязательно:
1) проверь реальный HEAD ветки;
2) проверь последний GitHub Actions run;
3) не называй CI/APK/device green без фактической проверки.

Ключевой текущий контекст:

Level2 ОБЯЗАТЕЛЬНО остаётся pseudo-3D. Не восстанавливай true-3D runtime трассы.

Главная текущая проблема — архитектура камеры 240SX.
Пользователь явно указал, что я раньше делал неправильно: я крутил/двигал Camera3D ВНУТРИ 3D-overlay автомобиля. Так делать больше нельзя.

Правильная архитектура:
- game_level2_pseudo3d.gd владеет основной camera/presentation state Level2;
- race_renderer_pseudo3d.gd потребляет этот state и строит относительно него pseudo-3D road/world;
- race_240sx_overlay.gd потребляет тот же state для экранного положения/pose автомобиля;
- Camera3D внутри Car3DOverlay — только фиксированная камера, которая красиво рендерит GLB. Она НЕ является игровой chase-camera и не должна иметь самостоятельный follow.

240SX надо сравнивать с исторической Окой как с визуальным эталоном.
Ока использовала screen-space контракт примерно:
car_w = 0.14 * width
car_h = car_w * 0.55
baseline = 0.985 * playfield height
lateral screen scale = 0.42
steering shift = 0.075 * width
steering tilt = 5 degrees
и texture footprint ~1.55x по ширине / 1.75x по высоте базовой коробки.

Пользователь хочет, чтобы 240SX:
- выглядела в той же композиции дороги;
- не была отдельным огромным 3D-объектом поверх трассы;
- имела top-rear / over-car view, а не камеру строго в зад;
- не «висела» над асфальтом;
- не обрезалась при повороте;
- сохраняла большой прозрачный viewport независимо от видимого размера машины.

Дополнительные нерешённые gameplay-проблемы:
- машина слишком рано считает себя на обочине и режет скорость, пока визуально ещё находится на асфальте;
- при нулевой скорости машина не должна скользить вправо/влево как по льду;
- steering/поворот должен быть близок по ощущению к аркадным гонкам.

ОЧЕНЬ ВАЖНО: пользователь отдельно попросил NFS Underground 2-style CAMERA И УПРАВЛЕНИЕ.

Это НЕ забывать и не заменять только визуальной настройкой 240SX.

Цель:
сделать NFS Underground 2-like chase camera + driving feel ПОВЕРХ текущего pseudo-3D, НЕ переводя Level2 в true-3D.

Нужны:
- плавная основная chase-camera;
- camera follow за lateral motion с инерцией;
- небольшой yaw/roll при повороте;
- look-ahead в сторону поворота;
- speed-dependent camera distance/FOV feel, где это можно достоверно сделать в pseudo-3D;
- более плавное руление;
- arcade grip/slip;
- небольшая разница между heading и travel vector;
- ощущение движения мира относительно камеры.

Границы:
- никаких свободных true-3D orbit/подмостовых/холмовых камер;
- не ломать pseudo-3D road projection;
- не класть NFS camera logic в Camera3D внутри 240SX overlay;
- по возможности оформить NFS-style как отдельный handling/presentation profile, чтобы NES Ferrari Grand Prix Challenge tribute mode тоже можно было сохранить.

Ferrari Grand Prix Challenge NES:
Level2 задуман как дань этой NES-гонке.
Из предыдущего исследования подтверждено:
- digital Left/Right steering;
- arcade-style handling, не simulation;
- при чрезмерной скорости в повороте возможны speed loss/off-road;
- визуальный steering/front-wheel response важен;
- exact source/ROM implementation не найден, поэтому не утверждай побайтное/исходниковое совпадение.

Порядок:
P0:
1) реальный HEAD + latest CI;
2) main-camera ownership;
3) fixed overlay Camera3D;
4) 240SX visual calibration against Oka;
5) off-road threshold;
6) zero-speed lateral lock;
7) device test.

P1:
8) NFS-style main camera;
9) NFS-style handling;
10) сохранить NES mode;
11) CI/device validation.

Git workflow:
- GitHub-first;
- маленькие targeted commits;
- после существенного изменения проверяй реальный CI;
- не создавай brittle source-string smoke checks, если можно сделать runtime behavioral assertion;
- если smoke contract намеренно меняется, обновляй его вместе с production change.

Начни с чтения HANDOFF_2026-10-07.md и проверки текущего HEAD/Actions.
