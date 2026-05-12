# PKU-DB-Proj3

PKU 2026 Spring 数据库概论实习三: 基于SQL的数据分析实习

## 任务一：基于SQL的数据预处理
这个任务的主要内容是利用SQL中的正则表达式、字符串和日期函数，完成对原始数据集的清洗。具体工作内容可以参考“数据预处理实习任务设计”文档，同学们要完成的事情是跑通文档中的代码，加入3~5项新的清洗任务，比如加入一个新字段，要求满足特定表达式约束等，形成最终的清洗前后的对比结果报告。有兴趣的同学可以调用Python中东额数据集的数据质量评估工具，对清洗前后的数据质量做个对比。

## 任务二：针对movielen数据集的分析查询
1.	列出平均得分前10的电影。
2.	列出每个类型的平均得分前10的电影。
3.	列出每个用户综合评价排在前5的电影类型。
4.	列出每个用户观影次数排在前5的电影类型。
5.	列出兴趣相同的用户对，主要是基于他们相同的观影记录做分析，满足如下条件：
    - 统计每个类型下他们相同观影的次数，设置一个阈值，过滤掉那些相同观影次数太低的类型，剩下的相同观影类型的个数不少于一个阈值。
    - 他们观看相同电影时所给出的评价分的差值的标准差不大于一个阈值。

## 任务三：基于SQL实现各种熵的概念
熵是机器学习领域最基础最重要的概念，基于SQL实现各种熵，是数据库内置机器学习算法的基础。各种熵的概念以及如何用SQL实现它们，同学们可以参照“用 SQL 实现机器学习中的基础概念-熵”文档中的内容。
我们的实习任务是将上面的熵应用到“世界幸福指数数据集”上面，看看可以得到哪些有意义的结论。 “世界幸福指数数据集”各字段含义见文档说明。


## 执行顺序
```bash
mysql -u root -p --default-character-set=utf8mb4 < sql/00_create_database.sql
python scripts/load_raw_data.py --user root
mysql -u root -p --default-character-set=utf8mb4 dbproj3 < sql/task1_preprocessing.sql
mysql -u root -p --default-character-set=utf8mb4 dbproj3 < sql/task2_movielens_analysis.sql
mysql -u root -p --default-character-set=utf8mb4 dbproj3 < sql/task3_happiness_entropy.sql
python scripts/export_results.py --user root
jupyter notebook reports/final_report.ipynb
```