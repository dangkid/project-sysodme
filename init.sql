-- ============================================================
--  INIT.SQL — Ecosistema Empresarial Unificado
--  Se ejecuta AUTOMÁTICAMENTE en el PRIMER arranque de MariaDB
--  (montado en /docker-entrypoint-initdb.d/01-init.sql)
--
--  Contenido:
--    1. Creación de bases de datos (esquemas)
--    2. Usuarios y permisos
--    3. Tabla sys_companies (multi-tenant)
--    4. Tabla erp_users_extended
--    5. Tablas de negocio (historial clínico + inventario)
--    6. Procedimiento almacenado para la VISTA global de usuarios
--
--  ⚠️  Las contraseñas DEBEN coincidir con el archivo .env
-- ============================================================


-- ============================================================
--  1. CREAR BASES DE DATOS (ESQUEMAS)
-- ============================================================

CREATE DATABASE IF NOT EXISTS `db_landing`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci
  COMMENT 'WordPress — SANA Web (Landing)';

CREATE DATABASE IF NOT EXISTS `db_learning`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci
  COMMENT 'Moodle — SANA Academy (LMS)';

CREATE DATABASE IF NOT EXISTS `db_erp`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci
  COMMENT 'ERP & Gestión — ToolJet (Multi-tenant)';


-- ============================================================
--  2. CREAR USUARIOS Y ASIGNAR PERMISOS
--     ⚠️  Si cambias contraseñas aquí, actualiza también .env
-- ============================================================

-- WordPress → acceso exclusivo a db_landing
CREATE USER IF NOT EXISTS 'wp_user'@'%'
  IDENTIFIED BY 'WpDbSecur3Pass2026!';
GRANT ALL PRIVILEGES ON `db_landing`.* TO 'wp_user'@'%';

-- Moodle → acceso exclusivo a db_learning
CREATE USER IF NOT EXISTS 'moodle_user'@'%'
  IDENTIFIED BY 'MoodleDbSecur3Pass2026!';
GRANT ALL PRIVILEGES ON `db_learning`.* TO 'moodle_user'@'%';

-- ERP → acceso completo a db_erp + SELECT en db_learning (para la vista)
CREATE USER IF NOT EXISTS 'erp_user'@'%'
  IDENTIFIED BY 'ErpDbSecur3Pass2026!';
GRANT ALL PRIVILEGES ON `db_erp`.* TO 'erp_user'@'%';
GRANT SELECT ON `db_learning`.* TO 'erp_user'@'%';

FLUSH PRIVILEGES;


-- ============================================================
--  3. TABLA DE EMPRESAS — Multi-tenant
-- ============================================================

USE `db_erp`;

CREATE TABLE `sys_companies` (
  `id`           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `code`         VARCHAR(20)     NOT NULL UNIQUE
                   COMMENT 'Código interno (ej: SANA, GPP)',
  `name`         VARCHAR(150)    NOT NULL
                   COMMENT 'Razón social',
  `trade_name`   VARCHAR(150)    DEFAULT NULL
                   COMMENT 'Nombre comercial',
  `tax_id`       VARCHAR(20)     DEFAULT NULL
                   COMMENT 'NIF / CIF',
  `sector`       VARCHAR(100)    DEFAULT NULL
                   COMMENT 'Sector de actividad',
  `address`      TEXT            DEFAULT NULL,
  `phone`        VARCHAR(20)     DEFAULT NULL,
  `email`        VARCHAR(150)    DEFAULT NULL,
  `is_active`    TINYINT(1)      NOT NULL DEFAULT 1,
  `created_at`   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Tabla maestra de empresas del ecosistema';

INSERT INTO `sys_companies` (`id`, `code`, `name`, `trade_name`, `sector`, `is_active`)
VALUES
  (1, 'SANA',  'SANA Clínica y Formación S.L.',  'SANA',            'Salud / Formación',     1),
  (2, 'GPP',   'GP Producciones S.L.',            'GP Producciones', 'Eventos / Logística',   1),
  (3, 'NUEVA', 'Nueva Empresa S.L.',              'Nueva Empresa',   NULL,                    0);


-- ============================================================
--  4. USUARIOS EXTENDIDOS DEL ERP
-- ============================================================

CREATE TABLE `erp_users_extended` (
  `id`             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `company_id`     INT UNSIGNED    NOT NULL
                     COMMENT 'FK → sys_companies.id',
  `username`       VARCHAR(100)    NOT NULL UNIQUE,
  `email`          VARCHAR(255)    NOT NULL,
  `password_hash`  VARCHAR(255)    NOT NULL
                     COMMENT 'Almacenar con bcrypt / argon2',
  `first_name`     VARCHAR(100)    NOT NULL,
  `last_name`      VARCHAR(100)    NOT NULL,
  `role`           ENUM('admin','manager','employee','viewer')
                     NOT NULL DEFAULT 'viewer',
  `phone`          VARCHAR(20)     DEFAULT NULL,
  `is_active`      TINYINT(1)      NOT NULL DEFAULT 1,
  `last_login`     DATETIME        DEFAULT NULL,
  `created_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                     ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_erp_user_company` (`company_id`),
  INDEX `idx_erp_user_email`   (`email`),
  INDEX `idx_erp_user_role`    (`role`),
  CONSTRAINT `fk_erp_user_company`
    FOREIGN KEY (`company_id`) REFERENCES `sys_companies` (`id`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Usuarios internos del ERP (complementarios a Moodle)';

-- Datos de ejemplo (opcional, eliminar en producción)
INSERT INTO `erp_users_extended`
  (`company_id`, `username`, `email`, `password_hash`, `first_name`, `last_name`, `role`)
VALUES
  (1, 'admin.sana',   'admin@sana.es',          '$2y$10$placeholder_hash_change_me', 'Admin',   'SANA',   'admin'),
  (2, 'admin.gpp',    'admin@gpproducciones.es', '$2y$10$placeholder_hash_change_me', 'Admin',   'GPP',    'admin'),
  (1, 'dr.garcia',    'garcia@sana.es',          '$2y$10$placeholder_hash_change_me', 'Carlos',  'García', 'manager'),
  (2, 'logistica.gpp','logistica@gpproducciones.es','$2y$10$placeholder_hash_change_me','Laura', 'Martín', 'employee');


-- ============================================================
--  5. TABLAS DE NEGOCIO
-- ============================================================

-- ─────────────────────────────────────────────────────────────
--  5a. HISTORIAL CLÍNICO — Vinculado a SANA (company_id = 1)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE `med_clinical_history` (
  `id`              INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `user_id`         INT UNSIGNED    NOT NULL
                      COMMENT 'FK → erp_users_extended.id (paciente)',
  `company_id`      INT UNSIGNED    NOT NULL DEFAULT 1
                      COMMENT 'Siempre SANA (id=1)',
  `record_date`     DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `diagnosis`       TEXT            DEFAULT NULL,
  `treatment`       TEXT            DEFAULT NULL,
  `notes`           TEXT            DEFAULT NULL,
  `attending_dr`    VARCHAR(150)    DEFAULT NULL
                      COMMENT 'Nombre del profesional sanitario',
  `status`          ENUM('open','in_progress','closed','cancelled')
                      NOT NULL DEFAULT 'open',
  `attachments`     JSON            DEFAULT NULL
                      COMMENT 'Array de rutas a archivos adjuntos',
  `created_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                      ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_clinical_user`   (`user_id`),
  INDEX `idx_clinical_date`   (`record_date`),
  INDEX `idx_clinical_status` (`status`),
  CONSTRAINT `fk_clinical_user`
    FOREIGN KEY (`user_id`) REFERENCES `erp_users_extended` (`id`)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_clinical_company`
    FOREIGN KEY (`company_id`) REFERENCES `sys_companies` (`id`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Historiales clínicos de pacientes — exclusivo de SANA';


-- ─────────────────────────────────────────────────────────────
--  5b. INVENTARIO DE EVENTOS — Vinculado a company_id
--      (GP Producciones id=2, Nueva Empresa id=3)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE `evt_inventory` (
  `id`               INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `company_id`       INT UNSIGNED    NOT NULL
                       COMMENT 'FK → sys_companies.id (2=GPP, 3=Nueva)',
  `item_name`        VARCHAR(200)    NOT NULL,
  `category`         VARCHAR(100)    DEFAULT NULL
                       COMMENT 'Ej: Sonido, Iluminación, Escenografía',
  `description`      TEXT            DEFAULT NULL,
  `quantity`         INT             NOT NULL DEFAULT 0,
  `unit`             VARCHAR(20)     DEFAULT 'unidad'
                       COMMENT 'unidad, metro, kg, litro…',
  `unit_cost`        DECIMAL(10,2)   DEFAULT 0.00,
  `location`         VARCHAR(200)    DEFAULT NULL
                       COMMENT 'Almacén o ubicación física',
  `condition_status` ENUM('new','good','fair','damaged','retired')
                       NOT NULL DEFAULT 'good',
  `is_available`     TINYINT(1)      NOT NULL DEFAULT 1,
  `last_checked`     DATE            DEFAULT NULL,
  `created_at`       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`       TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
                       ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_inv_company`   (`company_id`),
  INDEX `idx_inv_category`  (`category`),
  INDEX `idx_inv_available` (`is_available`),
  CONSTRAINT `fk_inventory_company`
    FOREIGN KEY (`company_id`) REFERENCES `sys_companies` (`id`)
    ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Inventario de equipos para eventos';

-- Datos de ejemplo (opcional)
INSERT INTO `evt_inventory`
  (`company_id`, `item_name`, `category`, `quantity`, `unit_cost`, `location`, `condition_status`)
VALUES
  (2, 'Mesa de mezclas Yamaha TF3',    'Sonido',       2,  2500.00, 'Almacén A - Estante 1', 'good'),
  (2, 'Foco LED PAR 64 RGBW',         'Iluminación',  20, 85.00,   'Almacén A - Estante 3', 'good'),
  (2, 'Truss Triangular 3m',          'Escenografía', 12, 120.00,  'Almacén B',              'fair'),
  (2, 'Cable XLR 10m Neutrik',        'Sonido',       50, 15.00,   'Almacén A - Cajón 2',   'new');


-- ============================================================
--  6. VISTA GLOBAL DE USUARIOS — Procedimiento Almacenado
-- ============================================================
--
--  ¿Por qué un procedimiento y no un CREATE VIEW directo?
--  Porque db_learning.mdl_user AÚN NO EXISTE cuando MariaDB
--  ejecuta este script (Moodle crea sus tablas en su primer
--  arranque). El procedimiento se llama DESPUÉS de que Moodle
--  haya terminado su instalación inicial.
--
--  EJECUCIÓN (una sola vez, tras la primera carga de Moodle):
--
--    docker exec -i mariadb mariadb -u root \
--      -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
--      -e "CALL db_erp.sp_create_global_users_view();"
--
--  Después la vista queda disponible permanentemente:
--    SELECT * FROM db_erp.view_global_users;
--
-- ============================================================

DELIMITER //

CREATE PROCEDURE `sp_create_global_users_view`()
  COMMENT 'Crea/recrea la vista unificada Moodle + ERP. Llamar tras el primer boot de Moodle.'
BEGIN

  SET @view_sql = '
    CREATE OR REPLACE
      DEFINER = CURRENT_USER
      SQL SECURITY INVOKER
    VIEW `db_erp`.`view_global_users` AS

    /* ── Usuarios de Moodle (SANA Academy) ── */
    SELECT
      CONCAT(''moodle_'', m.id)                              AS global_id,
      ''moodle''                                              AS source_system,
      m.id                                                   AS source_id,
      m.username                                             AS username,
      m.email                                                AS email,
      m.firstname                                            AS first_name,
      m.lastname                                             AS last_name,
      CASE WHEN m.suspended = 0 THEN 1 ELSE 0 END           AS is_active,
      FROM_UNIXTIME(m.timecreated)                           AS created_at,
      FROM_UNIXTIME(m.timemodified)                          AS updated_at
    FROM `db_learning`.`mdl_user` m
    WHERE m.deleted = 0
      AND m.username NOT IN (''guest'', '''')

    UNION ALL

    /* ── Usuarios locales del ERP ── */
    SELECT
      CONCAT(''erp_'', e.id)                                 AS global_id,
      ''erp''                                                 AS source_system,
      e.id                                                   AS source_id,
      e.username                                             AS username,
      e.email                                                AS email,
      e.first_name                                           AS first_name,
      e.last_name                                            AS last_name,
      e.is_active                                            AS is_active,
      e.created_at                                           AS created_at,
      e.updated_at                                           AS updated_at
    FROM `db_erp`.`erp_users_extended` e
  ';

  PREPARE stmt FROM @view_sql;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  -- Confirmar creación
  SELECT 'Vista view_global_users creada/actualizada correctamente.' AS resultado;

END //

DELIMITER ;


-- ============================================================
--  SQL DIRECTO DE LA VISTA (referencia / ejecución manual)
--  Copiar y ejecutar manualmente si se prefiere al procedimiento:
-- ============================================================
--
--  CREATE OR REPLACE VIEW `db_erp`.`view_global_users` AS
--  SELECT
--    CONCAT('moodle_', m.id)                              AS global_id,
--    'moodle'                                              AS source_system,
--    m.id                                                  AS source_id,
--    m.username                                            AS username,
--    m.email                                               AS email,
--    m.firstname                                           AS first_name,
--    m.lastname                                            AS last_name,
--    CASE WHEN m.suspended = 0 THEN 1 ELSE 0 END          AS is_active,
--    FROM_UNIXTIME(m.timecreated)                          AS created_at,
--    FROM_UNIXTIME(m.timemodified)                         AS updated_at
--  FROM `db_learning`.`mdl_user` m
--  WHERE m.deleted = 0
--    AND m.username NOT IN ('guest', '')
--
--  UNION ALL
--
--  SELECT
--    CONCAT('erp_', e.id)                                  AS global_id,
--    'erp'                                                  AS source_system,
--    e.id                                                   AS source_id,
--    e.username                                             AS username,
--    e.email                                                AS email,
--    e.first_name                                           AS first_name,
--    e.last_name                                            AS last_name,
--    e.is_active                                            AS is_active,
--    e.created_at                                           AS created_at,
--    e.updated_at                                           AS updated_at
--  FROM `db_erp`.`erp_users_extended` e;
--

-- ============================================================
--  FIN DEL SCRIPT DE INICIALIZACIÓN
-- ============================================================
