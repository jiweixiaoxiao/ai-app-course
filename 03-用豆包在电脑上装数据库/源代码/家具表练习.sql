SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE practice;

CREATE TABLE IF NOT EXISTS furniture (
  `编号` INT NOT NULL COMMENT '家具编号',
  `家具名称` VARCHAR(100) NOT NULL COMMENT '家具名称',
  `数量` INT NOT NULL COMMENT '数量',
  `形状` VARCHAR(50) NOT NULL COMMENT '形状',
  `成色` VARCHAR(50) NOT NULL COMMENT '成色',
  `颜色` VARCHAR(50) NOT NULL COMMENT '颜色',
  PRIMARY KEY (`编号`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家具表';

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (1, '餐桌', 1, '正方形', '9成新', '棕色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (2, '餐椅', 4, '方形椅面', '8成新', '原木色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (3, '沙发', 1, 'L 形', '9成新', '灰色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (4, '书柜', 1, '长方形', '8成新', '白色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (5, '床头柜', 2, '正方形', '9成新', '米色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

INSERT INTO furniture (`编号`, `家具名称`, `数量`, `形状`, `成色`, `颜色`)
VALUES (6, '衣柜', 1, '长方形', '7成新', '深棕色') AS new
ON DUPLICATE KEY UPDATE
  `家具名称` = new.`家具名称`,
  `数量` = new.`数量`,
  `形状` = new.`形状`,
  `成色` = new.`成色`,
  `颜色` = new.`颜色`;

SELECT
  `编号`,
  `家具名称`,
  `数量`,
  `形状`,
  `成色`,
  `颜色`
FROM furniture
ORDER BY `编号`;
