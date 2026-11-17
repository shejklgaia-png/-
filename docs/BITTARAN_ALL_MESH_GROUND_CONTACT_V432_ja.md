# ビットタラン全メッシュ接地・床貫通調査（v432）

元データ：`models/storage/ビットタラン (1).bbmodel`（7クリップ）＋ゲーム用Blockbenchファイルの補助3クリップ。Blockbench座標Y=0を地面と仮定します。接触しきい値はY≤0.025 Blockbench単位。各アニメーションのキー時刻と120Hzの中間時刻で全18メッシュの頂点高さを評価。接地・貫通の期間は `assets/bittaran_ground_contacts.gd` に保存（秒単位）。クリップ間の補間、Godot上のIK、頭部追尾はこの基準アニメーションには含みません。

## 集計
| クリップ | 長さ (s) | 異なるキー時刻数 | 接触・貫通するメッシュ数 | 接地・貫通区間数 |
|---|---:|---:|---:|---:|
| Wait | 0.000 | 1 | 2 | 2 |
| なぎ払い | 1.500 | 7 | 6 | 6 |
| 弾き | 1.000 | 6 | 6 | 8 |
| 踏みつけ_L | 1.750 | 7 | 4 | 4 |
| なぎ払い_R | 1.500 | 7 | 5 | 5 |
| 弾き_R | 1.000 | 6 | 5 | 7 |
| 踏みつけ_R | 1.750 | 7 | 4 | 4 |
| Idle | 2.400 | 9 | 6 | 6 |
| Turn | 1.800 | 9 | 6 | 6 |
| Approach | 2.800 | 9 | 6 | 6 |

## 全キーフレーム判定
数値は各メッシュ最下部のBlockbench Y値。正数0.025以下は接触許容、負数は床貫通。

### Wait
- **0.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-0.3294、FrontFoot_L_Mesh [db1e4d84] Y=-0.3294

### なぎ払い
- **0.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.2500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-1.4195、FrontLowerLeg_L_Mesh [d7e54274] Y=-2.651、FrontFoot_L_Mesh [db1e4d84] Y=-3.2839、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.4167s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.6232、FrontLowerLeg_L_Mesh [d7e54274] Y=-1.2405、FrontFoot_L_Mesh [db1e4d84] Y=-1.298、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.5000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.4067、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.9843、FrontFoot_L_Mesh [db1e4d84] Y=-0.99、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.7500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.7969、FrontLowerLeg_L_Mesh [d7e54274] Y=-1.2779、FrontFoot_L_Mesh [db1e4d84] Y=-1.2763、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **1.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.1067、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.9923、FrontFoot_L_Mesh [db1e4d84] Y=-0.9214、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **1.5000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.1067、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.9923、FrontFoot_L_Mesh [db1e4d84] Y=-0.9214、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476

### 弾き
- **0.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontFoot_L_Mesh [db1e4d84] Y=-2.2439、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.2500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontFoot_L_Mesh [db1e4d84] Y=-2.2439、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.4583s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.6250s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLeg_L_Mesh [9a36d635] Y=-0.341、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.486、FrontFoot_L_Mesh [db1e4d84] Y=-0.164、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **0.7500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.9376、FrontFoot_L_Mesh [db1e4d84] Y=-1.067、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476
- **1.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.4714、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.9376、FrontFoot_L_Mesh [db1e4d84] Y=-1.067、RearFoot_R_Mesh [74f86e05] Y=-0.9245、RearFoot_L_Mesh [170d67ff] Y=-0.1476

### 踏みつけ_L
- **0.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **0.7500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.2500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.3750s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.5000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、FrontFoot_L_Mesh [db1e4d84] Y=-2.3225、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.7500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-1.8294、FrontFoot_L_Mesh [db1e4d84] Y=-2.3225、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098

### なぎ払い_R
- **0.0000s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.2500s**：FrontLeg_R_Mesh [0915bbb7] Y=-1.2393、FrontLowerLeg_R_Mesh [a56f4966] Y=-2.4707、FrontFoot_R_Mesh [fe1de7e7] Y=-3.1037、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.4167s**：FrontLeg_R_Mesh [0915bbb7] Y=-0.443、FrontLowerLeg_R_Mesh [a56f4966] Y=-1.0603、FrontFoot_R_Mesh [fe1de7e7] Y=-1.1178、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.5000s**：FrontLeg_R_Mesh [0915bbb7] Y=-0.2265、FrontLowerLeg_R_Mesh [a56f4966] Y=-0.804、FrontFoot_R_Mesh [fe1de7e7] Y=-0.8098、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.7500s**：FrontLeg_R_Mesh [0915bbb7] Y=-0.6167、FrontLowerLeg_R_Mesh [a56f4966] Y=-1.0977、FrontFoot_R_Mesh [fe1de7e7] Y=-1.0961、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **1.0000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.8121、FrontFoot_R_Mesh [fe1de7e7] Y=-0.7411、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **1.5000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.8121、FrontFoot_R_Mesh [fe1de7e7] Y=-0.7411、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443

### 弾き_R
- **0.0000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-2.0637、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.2500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-2.0637、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.4583s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.6250s**：FrontLeg_R_Mesh [0915bbb7] Y=-0.1607、FrontLowerLeg_R_Mesh [a56f4966] Y=-0.3057、FrontFoot_R_Mesh [fe1de7e7] Y=0.0163、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **0.7500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.7573、FrontFoot_R_Mesh [fe1de7e7] Y=-0.8868、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443
- **1.0000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.7573、FrontFoot_R_Mesh [fe1de7e7] Y=-0.8868、FrontFoot_L_Mesh [db1e4d84] Y=-1.2911、RearFoot_L_Mesh [170d67ff] Y=-0.7443

### 踏みつけ_R
- **0.0000s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **0.7500s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.0000s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.2500s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.3750s**：FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.5000s**：FrontFoot_R_Mesh [fe1de7e7] Y=-2.3225、FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098
- **1.7500s**：FrontFoot_R_Mesh [fe1de7e7] Y=-2.3225、FrontFoot_L_Mesh [db1e4d84] Y=-1.8294、RearFoot_R_Mesh [74f86e05] Y=-1.0098、RearFoot_L_Mesh [170d67ff] Y=-1.0098

### Idle
- **0.0000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **0.3000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.3755、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1485、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.3755、FrontFoot_L_Mesh [db1e4d84] Y=-7.1485、RearFoot_R_Mesh [74f86e05] Y=-6.4644、RearFoot_L_Mesh [170d67ff] Y=-6.4644
- **0.6000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.34、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1143、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.34、FrontFoot_L_Mesh [db1e4d84] Y=-7.1143、RearFoot_R_Mesh [74f86e05] Y=-6.4863、RearFoot_L_Mesh [170d67ff] Y=-6.4863
- **0.9000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.3755、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1485、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.3755、FrontFoot_L_Mesh [db1e4d84] Y=-7.1485、RearFoot_R_Mesh [74f86e05] Y=-6.4644、RearFoot_L_Mesh [170d67ff] Y=-6.4644
- **1.2000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **1.5000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.5442、FrontFoot_R_Mesh [fe1de7e7] Y=-7.3077、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5442、FrontFoot_L_Mesh [db1e4d84] Y=-7.3077、RearFoot_R_Mesh [74f86e05] Y=-6.3528、RearFoot_L_Mesh [170d67ff] Y=-6.3528
- **1.8000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.5785、FrontFoot_R_Mesh [fe1de7e7] Y=-7.3394、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5785、FrontFoot_L_Mesh [db1e4d84] Y=-7.3394、RearFoot_R_Mesh [74f86e05] Y=-6.3285、RearFoot_L_Mesh [170d67ff] Y=-6.3285
- **2.1000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.5442、FrontFoot_R_Mesh [fe1de7e7] Y=-7.3077、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5442、FrontFoot_L_Mesh [db1e4d84] Y=-7.3077、RearFoot_R_Mesh [74f86e05] Y=-6.3528、RearFoot_L_Mesh [170d67ff] Y=-6.3528
- **2.4000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098

### Turn
- **0.0000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **0.2250s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4337、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1789、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5659、FrontFoot_L_Mesh [db1e4d84] Y=-7.3209、RearFoot_R_Mesh [74f86e05] Y=-6.352、RearFoot_L_Mesh [170d67ff] Y=-6.5343
- **0.4500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4073、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1315、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.6263、FrontFoot_L_Mesh [db1e4d84] Y=-7.3647、RearFoot_R_Mesh [74f86e05] Y=-6.3318、RearFoot_L_Mesh [170d67ff] Y=-6.5685
- **0.6750s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4337、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1789、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5659、FrontFoot_L_Mesh [db1e4d84] Y=-7.3209、RearFoot_R_Mesh [74f86e05] Y=-6.352、RearFoot_L_Mesh [170d67ff] Y=-6.5343
- **0.9000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **1.1250s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.56、FrontFoot_R_Mesh [fe1de7e7] Y=-7.315、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4278、FrontFoot_L_Mesh [db1e4d84] Y=-7.1729、RearFoot_R_Mesh [74f86e05] Y=-6.5284、RearFoot_L_Mesh [170d67ff] Y=-6.346
- **1.3500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.6179、FrontFoot_R_Mesh [fe1de7e7] Y=-7.3564、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.3989、FrontFoot_L_Mesh [db1e4d84] Y=-7.1231、RearFoot_R_Mesh [74f86e05] Y=-6.5601、RearFoot_L_Mesh [170d67ff] Y=-6.3234
- **1.5750s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.56、FrontFoot_R_Mesh [fe1de7e7] Y=-7.315、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4278、FrontFoot_L_Mesh [db1e4d84] Y=-7.1729、RearFoot_R_Mesh [74f86e05] Y=-6.5284、RearFoot_L_Mesh [170d67ff] Y=-6.346
- **1.8000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098

### Approach
- **0.0000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **0.3500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.2977、FrontFoot_R_Mesh [fe1de7e7] Y=-7.0144、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4625、FrontFoot_L_Mesh [db1e4d84] Y=-7.1579、RearFoot_R_Mesh [74f86e05] Y=-6.5245、RearFoot_L_Mesh [170d67ff] Y=-6.6508
- **0.7000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.3939、FrontFoot_R_Mesh [fe1de7e7] Y=-7.0516、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.6174、FrontFoot_L_Mesh [db1e4d84] Y=-7.2187、RearFoot_R_Mesh [74f86e05] Y=-6.2868、RearFoot_L_Mesh [170d67ff] Y=-6.5153
- **1.0500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.5801、FrontFoot_R_Mesh [fe1de7e7] Y=-7.3003、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.7476、FrontFoot_L_Mesh [db1e4d84] Y=-7.4089、RearFoot_R_Mesh [74f86e05] Y=-6.2222、RearFoot_L_Mesh [170d67ff] Y=-6.3684
- **1.4000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098
- **1.7500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4591、FrontFoot_R_Mesh [fe1de7e7] Y=-7.1545、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.2944、FrontFoot_L_Mesh [db1e4d84] Y=-7.011、RearFoot_R_Mesh [74f86e05] Y=-6.6475、RearFoot_L_Mesh [170d67ff] Y=-6.5212
- **2.1000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.6126、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2139、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.3892、FrontFoot_L_Mesh [db1e4d84] Y=-7.0469、RearFoot_R_Mesh [74f86e05] Y=-6.5106、RearFoot_L_Mesh [170d67ff] Y=-6.2821
- **2.4500s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.7443、FrontFoot_R_Mesh [fe1de7e7] Y=-7.4056、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.5768、FrontFoot_L_Mesh [db1e4d84] Y=-7.2969、RearFoot_R_Mesh [74f86e05] Y=-6.3651、RearFoot_L_Mesh [170d67ff] Y=-6.2189
- **2.8000s**：FrontLowerLeg_R_Mesh [a56f4966] Y=-0.4605、FrontFoot_R_Mesh [fe1de7e7] Y=-7.2294、FrontLowerLeg_L_Mesh [d7e54274] Y=-0.4605、FrontFoot_L_Mesh [db1e4d84] Y=-7.2294、RearFoot_R_Mesh [74f86e05] Y=-6.4098、RearFoot_L_Mesh [170d67ff] Y=-6.4098

## 区間データ
### Wait
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–0s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–0s

### なぎ払い
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–1.5s
- FrontLeg_L_Mesh `9a36d635-79d7-b24d-442b-ed23382abb16`：0.1375–1.5s
- FrontLowerLeg_L_Mesh `d7e54274-bb0b-efe9-68a3-4ee1d1ccb653`：0.1375–1.5s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0.14583–1.5s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–1.5s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1.5s

### 弾き
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–1s
- FrontLeg_L_Mesh `9a36d635-79d7-b24d-442b-ed23382abb16`：0.55417–0.65417s
- FrontLowerLeg_L_Mesh `d7e54274-bb0b-efe9-68a3-4ee1d1ccb653`：0.35417–0.45417s、0.47083–1s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–0.45417s、0.47917–1s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–1s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1s

### 踏みつけ_L
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–1.75s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：1.47083–1.75s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–1.75s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1.75s

### なぎ払い_R
- FrontLeg_R_Mesh `0915bbb7-15f5-ac23-2520-1f53e8d7eab2`：0.14583–0.9875s
- FrontLowerLeg_R_Mesh `a56f4966-a6b4-2678-3998-ba8a2f25a486`：0.14583–1.5s
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0.15417–1.5s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–1.5s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1.5s

### 弾き_R
- FrontLeg_R_Mesh `0915bbb7-15f5-ac23-2520-1f53e8d7eab2`：0.5875–0.6375s
- FrontLowerLeg_R_Mesh `a56f4966-a6b4-2678-3998-ba8a2f25a486`：0.37083–0.4375s、0.52083–1s
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–0.45417s、0.5875–1s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–1s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1s

### 踏みつけ_R
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：1.47083–1.75s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–1.75s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–1.75s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1.75s

### Idle
- FrontLowerLeg_R_Mesh `a56f4966-a6b4-2678-3998-ba8a2f25a486`：0–2.4s
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–2.4s
- FrontLowerLeg_L_Mesh `d7e54274-bb0b-efe9-68a3-4ee1d1ccb653`：0–2.4s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–2.4s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–2.4s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–2.4s

### Turn
- FrontLowerLeg_R_Mesh `a56f4966-a6b4-2678-3998-ba8a2f25a486`：0–1.8s
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–1.8s
- FrontLowerLeg_L_Mesh `d7e54274-bb0b-efe9-68a3-4ee1d1ccb653`：0–1.8s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–1.8s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–1.8s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–1.8s

### Approach
- FrontLowerLeg_R_Mesh `a56f4966-a6b4-2678-3998-ba8a2f25a486`：0–2.8s
- FrontFoot_R_Mesh `fe1de7e7-0546-517b-1e8c-c81de2ee99f6`：0–2.8s
- FrontLowerLeg_L_Mesh `d7e54274-bb0b-efe9-68a3-4ee1d1ccb653`：0–2.8s
- FrontFoot_L_Mesh `db1e4d84-e854-ed70-a480-d5094b17d993`：0–2.8s
- RearFoot_R_Mesh `74f86e05-9f34-6a6f-e30c-791bdcde9ea9`：0–2.8s
- RearFoot_L_Mesh `170d67ff-837b-0141-b104-3cbdd15f77b6`：0–2.8s

※ `mesh` という重複名はelement UUIDで区別。これらの数値はファイルのジオメトリとキーフレームを使う幾何学的な評価で、Godotの実動作確認ではありません。
