-- Schema.
CREATE TABLE `machines` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `customerid` bigint(20) NOT NULL DEFAULT '0',
  `name` varchar(50) NOT NULL DEFAULT '',
  `ip` varchar(16) NOT NULL DEFAULT '',
  `deleted` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `idx_customerid` (`customerid`),
  KEY `idx_deleted` (`deleted`),
  KEY `idx_ip` (`ip`)
);

CREATE TABLE `customers` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`)
);

-- Seed data.
INSERT INTO `customers` (id, name)
VALUES
  (1, 'Dan the Man Studios'),
  (2, 'Super Duper Games');

INSERT INTO `machines` (customerid, name, ip)
VALUES
  (1, 'dms-001', '1.2.3.4'),
  (1, 'dms-002', '2.3.4.5'),
  (1, 'dms-003', '3.4.5.6'),
  (2, 'sdg-001', '6.7.8.9'),
  (2, 'sdg-002', '7.8.9.10'),
  (2, 'sdg-003', '8.9.10.11');