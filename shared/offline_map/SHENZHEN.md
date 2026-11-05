# 深圳内置离线底图

用于 iPhone App 0.3.7（12）。安装包只包含 `shenzhen-v1.sqlite`，移除济南 SQLite 和济南示例底图的 App 资源引用。济南样本仅保留于仓库测试资料，不进入新版 App 包。

地图为道路和建筑矢量底图；不是离线搜索、离线路线规划或实时路况。深圳窗口从随 App 安装的数据库读取，不要求 R2 或在线地图服务。超出地图范围时不会显示济南示例冒充当地底图。旧版的在线地图缓存与手动下载管理仍保留，用于用户另行配置的其他地区。

来源：OpenStreetMap / Geofabrik Guangdong，固定快照 `guangdong-261103.osm.pbf`，MD5 `12b9b7acfbadd9da69e493f38830f3f8`。提取 OSM 深圳市行政边界 relation **3464353**；对真实道路和建筑进行边界相交裁剪。元数据保存在数据库和 `shenzhen-v1.manifest.json`，包含输入 SHA-256、数据时间及数量。OSM 对部分道路或建筑可能缺少记录，不补画虚构数据。

原始坐标为 WGS84，构建时转换一次 GCJ-02 E6，供现有高德路线和 BLE MapScene 使用。道路、建筑分别建立 SQLite R-tree；圆屏接收车辆周边窗口，不存储整市地图。

构建需 Python 3.12（`osmium==4.3.2`、`shapely==2.2.0`）、Node.js 24：

```bash
python3 -m pip install osmium==4.3.2 shapely==2.2.0
bash scripts/offline_map/prepare_shenzhen.sh
```

生成器重用现有 v1 Schema 与编码规则；校验逐条检查几何、坐标、R-tree、数据库完整性、深圳查询和济南排除。iOS 测试检查新数据库随包存在、旧数据库／旧地图示例随包缺席，以及深圳地图读取不触发在线分块请求。

地图数据 © OpenStreetMap contributors，ODbL 1.0：

- https://www.openstreetmap.org/copyright
- https://opendatacommons.org/licenses/odbl/1-0/
- https://download.geofabrik.de/asia/china/guangdong.html

应用地图页面保留可访问的来源署名；项目原创代码许可不改变地图数据的 ODbL 许可。
