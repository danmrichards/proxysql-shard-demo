-- Seed data.
INSERT INTO `customers` (id, name)
VALUES
  (1, 'Dan the Man Studios'),
  (2, 'Super Duper Games'),
  (3, 'Acme Inc');

INSERT INTO `machines` (customerid, name, ip)
VALUES
  (1, 'dms-001', '1.2.3.4'),
  (1, 'dms-002', '2.3.4.5'),
  (1, 'dms-003', '3.4.5.6'),
  (2, 'sdg-001', '6.7.8.9'),
  (2, 'sdg-002', '7.8.9.10'),
  (2, 'sdg-003', '8.9.10.11');