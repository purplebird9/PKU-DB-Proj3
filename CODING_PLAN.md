# 数据库实习三 Coding Plan

## 0. 作业范围

根据《实习三：数据科学项目实习.docx》，本项目完成：

- 任务一：基于 SQL 的数据预处理。
- 任务二：针对 MovieLens 数据集的分析查询。
- 任务三：基于 SQL 实现各种熵的概念，并应用到世界幸福指数数据集。

最终交付: SQL 脚本使用 Python 内置 `sqlite3` 在本地 SQLite 数据库中运行并导出结果 CSV，Jupyter Notebook 读取这些 CSV 生成图表、解释结果并作为最终报告。不再依赖 MySQL Server、MySQL Workbench 或 `mysql.exe` 命令行客户端；少量 SQLite 缺失函数由 Python 注册实现，如 `REGEXP_REPLACE()`、`REGEXP`、`STDDEV_SAMP()`。

## 1. 项目目录规划

在 `PKU-DB-Proj3` 下组织如下文件：

```text
PKU-DB-Proj3/
  README.md
  CODING_PLAN.md
  sql/
    00_create_database.sql
    task1_preprocessing.sql
    task2_movielens_analysis.sql
    task3_happiness_entropy.sql
  reports/
    final_report.ipynb
    task1_cleaning_report.md
    task2_movielens_report.md
    task3_entropy_report.md
    assets/
  results/
    task1_before_after.csv
    task2_top_movies.csv
    task2_genre_top_movies.csv
    task2_user_top_rating_genres.csv
    task2_user_top_watch_genres.csv
    task2_similar_users.csv
    task3_entropy_metrics.csv
    task3_feature_importance.csv
  data/
    README.md
```

`data/` 不直接提交大 CSV，可在 `data/README.md` 中说明原始数据来自工作区上级目录：

- `../movielen数据集/movies.csv`
- `../movielen数据集/ratings.csv`
- `../世界幸福指数数据集/2015.csv` 到 `2019.csv`

Notebook 不直接承担核心 SQL 计算，避免报告执行时依赖本机数据库连接状态。推荐流程是：先运行 `sql/` 下脚本并导出 `results/` 中的 CSV，再由 `reports/final_report.ipynb` 使用 `pandas.read_csv()` 读取结果、生成表格和可视化。

## 2. 公共数据库准备

### 2.1 建库脚本

文件：`sql/00_create_database.sql`

实现内容：

1. 创建本地 SQLite 数据库文件 `data/dbproj3.sqlite`。
2. 创建三个逻辑分区表组：
   - 任务一：`user_raw_data`、`user_standard_data`。
   - 任务二：`movies`、`ratings`、`movie_genres`。
   - 任务三：`happiness_raw_2015` 到 `happiness_raw_2019`、`happiness`、`happiness_binned`。
3. 给常用连接字段加索引：
   - `ratings(movieId)`、`ratings(userId)`。
   - `movies(movieId)`。
   - `movie_genres(movieId)`、`movie_genres(genre)`。
   - `happiness(year)`、`happiness(country)`。

### 2.2 数据导入策略

MovieLens 数据：

- `movies.csv` 列：`movieId,title,genres`。
- `ratings.csv` 列：`userId,movieId,rating,timestamp`。
- 导入后把 `movies.genres` 中的 `Adventure|Animation|...` 拆成一行一个类型，写入 `movie_genres(movieId, genre)`。

幸福指数数据：

- 2015-2017 与 2018-2019 字段命名不同，先分别导入 raw 表，再统一写入标准表 `happiness`。
- 统一后的核心字段：
  - `year`
  - `overall_rank`
  - `country`
  - `region`
  - `score`
  - `gdp_per_capita`
  - `social_support`
  - `healthy_life_expectancy`
  - `freedom`
  - `generosity`
  - `perceptions_of_corruption`

字段映射规则：

| 标准字段 | 2015-2017 字段 | 2018-2019 字段 |
| --- | --- | --- |
| `overall_rank` | `Happiness Rank` / `Happiness.Rank` | `Overall rank` |
| `country` | `Country` | `Country or region` |
| `score` | `Happiness Score` / `Happiness.Score` | `Score` |
| `gdp_per_capita` | `Economy (GDP per Capita)` / `Economy..GDP.per.Capita.` | `GDP per capita` |
| `social_support` | `Family` | `Social support` |
| `healthy_life_expectancy` | `Health (Life Expectancy)` / `Health..Life.Expectancy.` | `Healthy life expectancy` |
| `freedom` | `Freedom` | `Freedom to make life choices` |
| `perceptions_of_corruption` | `Trust (Government Corruption)` / `Trust..Government.Corruption.` | `Perceptions of corruption` |
| `generosity` | `Generosity` | `Generosity` |

## 3. 任务一：SQL 数据预处理

文件：`sql/task1_preprocessing.sql`

### 3.1 基础要求

复现《SQL数据预处理实习任务设计.docx》中的原始表和脏数据：

- `raw_name`
- `raw_phone`
- `raw_email`
- `raw_register_time`
- `raw_address`
- `raw_age`
- `raw_remark`

完成原文 8 个清洗任务：

1. 姓名标准化。
2. 手机号清洗。
3. 邮箱格式校验与清洗。
4. 注册时间标准化。
5. 地址精简。
6. 年龄数值化。
7. 备注空值处理。
8. 整合输出 `user_standard_data`。

### 3.2 对原始参考 SQL 的增强

原文 SQL 可以跑通，并加入 3-5 项新的清洗任务：

1. 中文姓名合法性校验：
   - 清洗后姓名必须匹配 `^[一-龥]{2,10}$`。
   - 英文名、特殊字符名标记为 `无效姓名`。
2. 中国大陆手机号段校验：
   - 去掉 `86` 前缀后，必须匹配 `^1[3-9][0-9]{9}$`。
   - `129...` 这类长度正确但号段错误的数据标记为 `无效手机号`。
3. 邮箱域名修正与风险标记：
   - 统一转小写、去空格。
   - `qq..com`、双 `@@`、缺失用户名或域名都标记为 `无效邮箱`。
   - 输出 `email_domain` 字段，便于统计邮箱服务商。
4. 注册时间有效区间校验：
   - 只接受 `2024-01-01` 到 `2024-12-31` 范围内日期。
   - 超出范围或无法解析标记为 `无效日期`。
5. 地址城市提取：
   - 从地址中提取省/市级信息，例如 `北京市`、`上海市`、`杭州市`。
   - 增加 `city_name` 字段，用于后续地区分布统计。

### 3.3 关键 SQL 设计

建议用 CTE 分层实现，减少重复表达式：

1. `base_clean`：
   - 去除空格。
   - 提取手机号纯数字。
   - 邮箱转小写。
   - 日期字符串标准化。
2. `validated`：
   - 用 `CASE WHEN` 做合法性校验。
   - 产出每个字段的标准值和状态标签。
3. `CREATE TABLE user_standard_data AS SELECT ...`：
   - 写入最终标准化表。
4. `SELECT raw.*, standard.*`：
   - 输出清洗前后对比结果，用于 `results/task1_before_after.csv`。

### 3.4 验证与报告

报告位置：`reports/final_report.ipynb` 的“任务一：数据预处理”章节。`reports/task1_cleaning_report.md` 可作为草稿或附录保留。

必须包含：

- 原始脏数据样例。
- 每个字段的清洗规则。
- 新增 5 项清洗任务说明。
- 清洗前后对比表。
- 无效值数量统计，例如：
  - 无效姓名数。
  - 无效手机号数。
  - 无效邮箱数。
  - 无效日期数。
  - 未知年龄数。

## 4. 任务二：MovieLens 分析查询

文件：`sql/task2_movielens_analysis.sql`

### 4.1 数据表设计

```sql
CREATE TABLE movies (
  movieId INT PRIMARY KEY,
  title VARCHAR(255),
  genres VARCHAR(255)
);

CREATE TABLE ratings (
  userId INT,
  movieId INT,
  rating DECIMAL(2,1),
  rating_ts BIGINT,
  INDEX idx_ratings_movie (movieId),
  INDEX idx_ratings_user (userId)
);

CREATE TABLE movie_genres (
  movieId INT,
  genre VARCHAR(100),
  INDEX idx_movie_genres_movie (movieId),
  INDEX idx_movie_genres_genre (genre)
);
```

`movie_genres` 使用 SQLite 递归 CTE 拆分 `genres`，不依赖 MySQL 专有函数。

### 4.2 查询 1：平均得分前 10 的电影

规则：

- 按 `movieId` 聚合。
- 输出 `title`、评分次数、平均分。
- 为避免单次高分电影刷榜，加入最低评分次数阈值，建议 `rating_count >= 20`。
- 排序：`avg_rating DESC, rating_count DESC`。

输出：`results/task2_top_movies.csv`

### 4.3 查询 2：每个类型平均得分前 10 的电影

规则：

- 先把电影类型拆开，一部电影可以属于多个类型。
- 对 `(genre, movieId)` 聚合平均分。
- 每个 `genre` 内使用 `ROW_NUMBER() OVER (PARTITION BY genre ORDER BY avg_rating DESC, rating_count DESC)`。
- 保留 `rank <= 10`。
- 建议仍加入 `rating_count >= 10` 或 `>= 20` 的阈值。

输出：`results/task2_genre_top_movies.csv`

### 4.4 查询 3：每个用户综合评价排前 5 的电影类型

“综合评价”建议定义为用户对某类型的平均评分，同时加入观看次数作为辅助排序。

规则：

- 连接 `ratings -> movie_genres`。
- 对 `(userId, genre)` 聚合：
  - `avg_user_genre_rating`
  - `watch_count`
- 为避免用户只看 1 部就被认为偏好极强，建议 `watch_count >= 2`。
- 用窗口函数对每个用户排名，保留前 5。

输出：`results/task2_user_top_rating_genres.csv`

### 4.5 查询 4：每个用户观影次数前 5 的电影类型

规则：

- 对 `(userId, genre)` 统计 `watch_count`。
- 每个用户按 `watch_count DESC, avg_rating DESC` 排名。
- 保留前 5。

输出：`results/task2_user_top_watch_genres.csv`

### 4.6 查询 5：兴趣相同的用户对

这是任务二最复杂的部分，分两层过滤。

#### 4.6.1 基础用户对

构造用户对 `(user_a, user_b)`：

- 同一部电影被两个用户都看过。
- 用 `r1.userId < r2.userId` 避免重复和自连接。
- 得到共同观看电影、共同观看类型、评分差。

#### 4.6.2 类型共同观影阈值

对 `(user_a, user_b, genre)` 聚合：

- `common_watch_count = COUNT(DISTINCT movieId)`。
- 设置阈值 `common_watch_count >= 3`。

再对 `(user_a, user_b)` 聚合：

- 满足阈值的共同兴趣类型数量 `qualified_common_genre_count`。
- 设置阈值 `qualified_common_genre_count >= 2`。

#### 4.6.3 评分差标准差阈值

对 `(user_a, user_b)` 聚合所有共同观看电影的评分差：

- `STDDEV_SAMP(rating_a - rating_b) AS rating_diff_stddev`。
- 设置阈值 `rating_diff_stddev <= 0.75`。

#### 4.6.4 最终输出

输出字段：

- `user_a`
- `user_b`
- `qualified_common_genre_count`
- `total_common_movies`
- `rating_diff_stddev`
- `common_genres`

排序：

- `qualified_common_genre_count DESC`
- `total_common_movies DESC`
- `rating_diff_stddev ASC`

输出：`results/task2_similar_users.csv`

### 4.7 验证与报告

报告位置：`reports/final_report.ipynb` 的“任务二：MovieLens 分析查询”章节。`reports/task2_movielens_report.md` 可作为草稿或附录保留。

必须包含：

- 数据规模：电影数、评分数、用户数、类型数。
- 五个查询的 SQL 思路。
- 每个查询的 Top 结果表。
- 对阈值的解释：为什么设置最低评分次数、共同观影次数、标准差阈值。

## 5. 任务三：幸福指数数据集熵分析

文件：`sql/task3_happiness_entropy.sql`

### 5.1 分析目标

把“熵、条件熵、信息增益、信息增益率、基尼系数、联合熵、互信息”等概念应用到世界幸福指数数据集，回答：

- 幸福指数高/中/低类别本身有多混乱？
- GDP、社会支持、健康寿命、自由、慷慨、腐败感知等因素中，哪个对幸福类别的信息增益最大？
- 不同年份中，影响幸福分类的重要因素是否变化？
- 哪些指标和幸福类别之间的互信息更高？

### 5.2 数据标准化

创建统一表：

```sql
CREATE TABLE happiness (
  year INT,
  overall_rank INT,
  country VARCHAR(100),
  region VARCHAR(100),
  score DECIMAL(6,3),
  gdp_per_capita DECIMAL(8,4),
  social_support DECIMAL(8,4),
  healthy_life_expectancy DECIMAL(8,4),
  freedom DECIMAL(8,4),
  generosity DECIMAL(8,4),
  perceptions_of_corruption DECIMAL(8,4)
);
```

注意：

- 2015-2016 有 `Region`，2017-2019 缺少地区时可填 `NULL`。
- 2015-2017 的 `Family` 映射为 `social_support`。
- 2015-2017 的 `Trust (Government Corruption)` 映射为 `perceptions_of_corruption`。

### 5.3 连续特征分桶

熵分析需要离散标签和离散特征，因此建立 `happiness_binned`：

```sql
CREATE TABLE happiness_binned AS
SELECT
  *,
  CASE
    WHEN score >= 6.0 THEN 'high'
    WHEN score >= 4.5 THEN 'middle'
    ELSE 'low'
  END AS score_level,
  NTILE(3) OVER (PARTITION BY year ORDER BY gdp_per_capita) AS gdp_bin,
  NTILE(3) OVER (PARTITION BY year ORDER BY social_support) AS social_support_bin,
  NTILE(3) OVER (PARTITION BY year ORDER BY healthy_life_expectancy) AS health_bin,
  NTILE(3) OVER (PARTITION BY year ORDER BY freedom) AS freedom_bin,
  NTILE(3) OVER (PARTITION BY year ORDER BY generosity) AS generosity_bin,
  NTILE(3) OVER (PARTITION BY year ORDER BY perceptions_of_corruption) AS corruption_bin
FROM happiness;
```

分桶解释：

- `score_level` 是分类标签。
- 各指标用 `NTILE(3)` 按年份分成低、中、高三档，避免不同年份量纲或分布差异影响结果。

### 5.4 基础熵指标

计算标签熵 `H(Y)`：

- `Y = score_level`。
- 可以按全数据计算，也可以按年份计算。
- 解释：幸福类别越平均，熵越高；某一年高/中/低分布越集中，熵越低。

计算基尼系数：

- 用于辅助衡量幸福类别纯度。
- 和熵一起作为类别分布混乱程度指标。

输出：`results/task3_entropy_metrics.csv`

### 5.5 特征条件熵、信息增益和信息增益率

对每个候选特征分别计算：

- `H(Y|X)`：给定某个指标分桶后，幸福类别仍有多少不确定性。
- `IG(Y, X) = H(Y) - H(Y|X)`：该指标能减少多少不确定性。
- `GainRatio = IG / H(X)`：修正高取值数特征的偏置。

候选特征：

- `gdp_bin`
- `social_support_bin`
- `health_bin`
- `freedom_bin`
- `generosity_bin`
- `corruption_bin`

输出：

- `feature_name`
- `year`
- `entropy_y`
- `conditional_entropy`
- `information_gain`
- `feature_entropy`
- `gain_ratio`

排序：

- `year ASC`
- `information_gain DESC`

输出：`results/task3_feature_importance.csv`

### 5.6 联合熵与互信息

选择两个最重要特征做联合分析，例如：

- `gdp_bin + social_support_bin`
- `social_support_bin + health_bin`
- `freedom_bin + corruption_bin`

计算：

- `H(X, Y)`：特征和幸福类别联合熵。
- `I(X;Y)`：互信息。
- `I((X1, X2);Y)`：双特征组合对幸福类别的信息量。

分析目标：

- 判断单个指标强，还是两个指标组合后更强。
- 例如 GDP 与社会支持是否组合后对幸福分层解释力更高。

### 5.7 结论写作方向

报告位置：`reports/final_report.ipynb` 的“任务三：幸福指数熵分析”章节。`reports/task3_entropy_report.md` 可作为草稿或附录保留。

建议结论结构：

1. 幸福类别总体分布：
   - 高/中/低国家数量。
   - 标签熵和基尼系数。
2. 单特征重要性：
   - 按信息增益排名。
   - 解释排名靠前的指标含义。
3. 年份变化：
   - 比较 2015-2019 各指标信息增益变化。
4. 联合特征：
   - 比较单指标和双指标互信息。
5. 总结：
   - 哪些因素最能区分幸福指数高/中/低国家。
   - SQL 实现熵分析的优势和限制。

## 6. Jupyter Notebook 最终报告

文件：`reports/final_report.ipynb`

Notebook 定位：

- 不在 Notebook 中重写全部 SQL 逻辑。
- SQL 脚本在 SQLite 中完成建表、清洗、查询、熵计算。
- Notebook 读取 `results/` 下已经导出的 CSV，负责展示结果、解释方法、绘制图表和形成最终报告。
- Notebook 中可以保留关键 SQL 片段作为 Markdown 或代码块，证明核心计算来自 SQL。

结构：

1. 任务说明。
2. 数据集说明。
3. 数据库表结构设计。
4. 任务一：数据预处理实现与结果。
5. 任务二：MovieLens 分析查询与结果。
6. 任务三：幸福指数熵分析与结论。
7. 可视化分析：
   - 任务一：清洗前后无效值数量对比。
   - 任务二：高分电影、类型 Top 结果、用户偏好类型分布。
   - 任务三：各特征信息增益排名、不同年份特征重要性变化。
8. 实验复现步骤。

Notebook 依赖：

```text
pandas
matplotlib
seaborn
jupyter
```

Notebook 读取 CSV 示例：

```python
import pandas as pd

task1 = pd.read_csv("../results/task1_before_after.csv")
top_movies = pd.read_csv("../results/task2_top_movies.csv")
entropy_metrics = pd.read_csv("../results/task3_entropy_metrics.csv")
feature_importance = pd.read_csv("../results/task3_feature_importance.csv")
```

为了保证报告可复现，Notebook 第一节应检查所有结果文件是否存在；如果缺失，提示先运行 `sql/` 下对应脚本并导出 CSV。

## 7. SQL 结果导出要求

所有核心查询都通过 Python 内置 `sqlite3` 执行，并导出到 `results/`。使用命令行时采用如下方式：

```bash
python scripts/run_sqlite_pipeline.py
```

结果导出可以用以下任一方式完成：

- `scripts/run_sqlite_pipeline.py` 一次性建库、导入数据、执行 SQL 并导出 CSV。
- `scripts/export_results.py` 可从已有 `data/dbproj3.sqlite` 重新导出 CSV。

推荐为每个最终查询都建立视图，导出时只需要：

```sql
SELECT * FROM v_task2_top_movies;
SELECT * FROM v_task3_feature_importance;
```

## 8. 推荐实现顺序

1. 创建项目目录与 `00_create_database.sql`。
2. 完成任务一 SQL，因为它完全基于文档内置数据，最容易先跑通。
3. 导入 MovieLens CSV，完成 `movie_genres` 拆分。
4. 实现任务二前 4 个查询，再实现用户相似度查询。
5. 导入幸福指数 2015-2019 CSV，统一字段到 `happiness`。
6. 建立 `happiness_binned`，先计算基础熵，再计算信息增益。
7. 导出所有结果 CSV。
8. 编写 `reports/final_report.ipynb`，读取 CSV、展示表格、生成图表并撰写分析文字。
9. 可选：保留三个 Markdown 子报告作为草稿或附录，但最终交付以 Notebook 为主。
10. 最后重新从空库执行所有 SQL，确认项目可复现；再重启 Notebook 内核并从头运行，确认报告可复现。

## 9. 验收清单

- [ ] `task1_preprocessing.sql` 能从建表、插入脏数据到生成标准表完整跑通。
- [ ] 任务一包含原要求 8 项清洗和新增 5 项清洗。
- [ ] `task2_movielens_analysis.sql` 覆盖 MovieLens 5 个查询要求。
- [ ] 用户相似度查询同时包含共同类型数量阈值和评分差标准差阈值。
- [ ] `task3_happiness_entropy.sql` 覆盖信息熵、条件熵、信息增益、信息增益率、基尼系数、联合熵/互信息。
- [ ] 幸福指数 2015-2019 字段已统一。
- [ ] 所有 SQL 文件从空库可重复执行。
- [ ] `results/` 中有主要查询结果。
- [ ] `reports/final_report.ipynb` 能从 `results/` 读取 CSV 并完整运行。
- [ ] Notebook 中包含任务说明、关键 SQL 思路、结果表格、必要图表和实验结论。
- [ ] Notebook 重启内核后从头运行无报错。
