-- 1. Lister les personnages ayant bu plus de 2 potions différentes.
SELECT p.nom_personnage AS "Personnage", COUNT(DISTINCT b.id_potion) AS "Potions différentes bu"
FROM personnage p
JOIN boire b ON p.id_personnage = b.id_personnage
GROUP BY p.id_personnage
HAVING COUNT(DISTINCT b.id_potion) > 2;

-- 2. Donner le total de casques pris par type, avec leur coût cumulé.
SELECT tc.nom_type_casque AS "Type", SUM(c.id_casque) AS "Nombre de casque", SUM(c.cout_casque * pc.qte) AS "Cout cumulé"
FROM casque c
JOIN type_casque tc ON tc.id_type_casque = c.id_type_casque
JOIN prendre_casque pc ON pc.id_casque = c.id_casque
GROUP BY c.id_type_casque;

-- 3. Pour chaque personnage, afficher le nombre de batailles auxquelles il a participé via la prise de casque.
SELECT p.nom_personnage AS "Personnage", COUNT(DISTINCT pc.id_bataille) AS "Batailles"
FROM personnage p
JOIN prendre_casque pc ON p.id_personnage = pc.id_personnage
GROUP BY p.id_personnage;

-- 4. Afficher les potions les plus bues (en dose totale).
SELECT p.nom_potion AS "Potion", SUM(b.dose_boire) AS "Dose totale"
FROM potion p
JOIN boire b ON p.id_potion = b.id_potion
GROUP BY b.id_potion
ORDER BY SUM(b.dose_boire) DESC;

-- 5. Afficher le top 5 des lieux dont les habitants ont bu le plus de potion (en dose totale), en incluant les égalités.
SELECT l.nom_lieu AS "Lieu", SUM(b.dose_boire) AS "Dose totale"
FROM personnage p
JOIN lieu l ON p.id_lieu = l.id_lieu
JOIN boire b ON b.id_personnage = p.id_personnage
GROUP BY l.id_lieu
HAVING SUM(b.dose_boire) > 0
ORDER BY SUM(b.dose_boire) DESC
LIMIT 5;

-- 6. Lister les potions autorisées pour un personnage mais jamais bues par lui.
SELECT p.nom_potion AS "Potion autorisée mais pas bu"
FROM potion p
JOIN autoriser_boire ab ON p.id_potion = ab.id_potion
JOIN personnage per ON ab.id_personnage = per.id_personnage
WHERE per.id_personnage = 25  -- Personnage avec l'ID 25
AND p.id_potion NOT IN (
    SELECT b.id_potion
    FROM boire b
    WHERE b.id_personnage = per.id_personnage
);

-- 7. Afficher les personnages avec toutes les potions qu'ils ont bues dans une seule colonne séparée par des virgules.
SELECT p.nom_personnage AS "Personnage", GROUP_CONCAT(po.nom_potion SEPARATOR ', ') AS "Potions bues"
FROM personnage p
JOIN boire b ON p.id_personnage = b.id_personnage
JOIN potion po ON b.id_potion = po.id_potion
GROUP BY p.id_personnage, p.nom_personnage
ORDER BY p.nom_personnage;

-- 8. Donner la moyenne de doses bues par spécialité (avec gestion des cas sans consommation).
SELECT s.nom_specialite AS "Spécialité",
       AVG(b.dose_boire) AS "Moyenne de doses bues",
       COUNT(DISTINCT p.id_personnage) AS "Nombre de personnages",
       COUNT(DISTINCT b.id_potion) AS "Nombre de potions différentes"
FROM specialite s
LEFT JOIN personnage p ON s.id_specialite = p.id_specialite
LEFT JOIN boire b ON p.id_personnage = b.id_personnage
WHERE b.dose_boire IS NOT NULL
GROUP BY s.id_specialite, s.nom_specialite
ORDER BY AVG(b.dose_boire) DESC;

-- 9. Lister les personnages ayant bu au moins 3 potions différentes le même jour.
SELECT p.nom_personnage AS "Personnage", COUNT(DISTINCT b.id_potion) AS "Potions différentes", DATE(b.date_boire) AS "Date"
FROM personnage p
LEFT JOIN boire b ON p.id_personnage = b.id_personnage
GROUP BY p.id_personnage, DATE(b.date_boire)
HAVING COUNT(DISTINCT b.id_potion) >= 3
ORDER BY DATE(b.date_boire), p.nom_personnage;

-- 10. Créer un trigger qui empêche un personnage de boire une potion non autorisée.
CREATE TRIGGER check_potion_authorization
    BEFORE INSERT ON boire
    FOR EACH ROW
BEGIN
    DECLARE authorized_count INT;

    -- Vérifier si la potion est autorisée pour le personnage
    SELECT COUNT(*)
    INTO authorized_count
    FROM autoriser_boire ab
    WHERE ab.id_potion = NEW.id_potion
    AND ab.id_personnage = NEW.id_personnage;

    -- Si la potion n'est pas autorisée, lever une erreur
    IF authorized_count = 0 THEN
        SIGNAL SQLSTATE "45000"
        SET MESSAGE_TEXT = "Cette potion n\'est pas autorisée pour ce personnage.";
    END IF;
END;

-- 11. Créer une procédure stockée permettant de savoir quelles potions un personnage peut consommer à partir d’une liste d’identifiants.
DELIMITER //
CREATE PROCEDURE get_authorized_potions(IN character_id INT)
BEGIN
    SELECT p.nom_potion AS "Potion autorisée"
    FROM potion p
    JOIN autoriser_boire ab ON p.id_potion = ab.id_potion
    WHERE ab.id_personnage = character_id;
END //
DELIMITER ;

-- Pour tester la procédure :
CALL get_authorized_potions(22);

-- 12. Créer une procédure stockée qui met à jour la quantité de casques disponibles après une prise.
DELIMITER //
CREATE PROCEDURE update_available_helmet_quantity(IN helmet_id INT, IN quantity INT)
BEGIN
    UPDATE prendre_casque
    SET qte = qte - quantity
    WHERE id_casque = helmet_id;
END //
DELIMITER ;

-- Pour tester la procédure :
CALL update_available_helmet_quantity(14, 1);

-- 13. Créer un index pertinent pour accélérer les recherches de casques pris par bataille.
CREATE INDEX idx_prendre_casque_bataille ON prendre_casque(id_bataille);

-- 14. Proposer une amélioration du modèle pour normaliser les moments de consommation de potion.
-- Pour normaliser les moments de consommation de potion, on pourrait créer une table `moment_consommation` qui stocke les moments de consommation (par exemple, matin, après-midi, soir) et lier cette table à la table `boire` via un champ `id_moment_consommation`.

CREATE TABLE moment_consommation (
    id_moment_consommation INT AUTO_INCREMENT PRIMARY KEY,
    nom_moment VARCHAR(50) NOT NULL
);

ALTER TABLE boire
ADD COLUMN id_moment_consommation INT,
ADD FOREIGN KEY (id_moment_consommation) REFERENCES moment_consommation(id_moment_consommation);

-- 15. Créer une requête permettant de générer un journal des consommations : personnage, date, potion, dose, lieu.
CREATE VIEW journal_de_consommations AS
SELECT p.nom_personnage AS "Personnage",
       b.date_boire AS "Date",
       po.nom_potion AS "Potion",
       b.dose_boire AS "Dose",
       l.nom_lieu AS "Lieu"
FROM boire b
         LEFT JOIN personnage p ON b.id_personnage = p.id_personnage
         LEFT JOIN potion po ON b.id_potion = po.id_potion
         LEFT JOIN lieu l ON p.id_lieu = l.id_lieu
ORDER BY b.date_boire DESC, p.nom_personnage;

-- Bonus 1 – Détection de tricheurs
-- Lister les personnages qui ont bu la même potion plus de 3 fois dans la même journée.
-- Afficher : nom du personnage, nom de la potion, date, nombre de fois.

-- Bonus 2 – Requête paramétrée pour historique personnalisé
-- Écrire une procédure stockée qui, à partir d’un id_personnage en entrée, retourne toutes les potions bues avec les dates et les doses, triées par date décroissante.

-- Bonus 3 – Verrouillage métier avec BEFORE INSERT
-- Écrire un trigger empêchant un personnage de prendre un casque s’il en a déjà pris plus de 10 au total dans toutes les batailles.

-- Bonus 4 – Optimisation
-- Quel index créer pour accélérer les recherches des potions bues par date et par personnage ?
-- Justifier votre choix avec la structure de la table boire.

-- Bonus 5 – Génération d’un résumé métier
-- Pour chaque spécialité, afficher le nombre total de personnages, le total de potions bues, et la moyenne de doses par personnage.
-- Afficher aussi la spécialité même si personne n’a encore bu.