CREATE OR REPLACE FUNCTION provjera_predmeta()
RETURNS TRIGGER AS
    $$
    BEGIN
       IF (SELECT COUNT(*) FROM alias A
            INNER JOIN student_alias sa on A.alias = sa.alias and sa.broj_idx = new.broj_idx AND
                                           A.predmet_id = (SELECT predmet_id FROM alias WHERE alias = new.alias)) > 0 THEN
           RAISE 'Dva puta unesen isti predmet za jednog studenta! %', new.broj_idx;
       END IF;
       RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    

-- FUNCKIJA KOJA ISPISUJE PITANJA ZA ANKETU
-- PARAMETAR tp JE ZA NAGLAŠAVANJE VRSTE PITANJA(ASISTENT, PROF ILI PREDMET)
CREATE OR REPLACE FUNCTION anketa(al varchar, tp int)
RETURNS TABLE (qid int, question varchar, typ int, id varchar) AS
    $$
    DECLARE
        pr_id int := (SELECT predmet_id FROM alias INNER JOIN student_alias sa on alias.alias = sa.alias and sa.alias = al);
        smj_id int := (SELECT smjer_id FROM alias INNER JOIN student_alias sa on alias.alias = sa.alias and sa.alias = al);
    BEGIN
        CASE tp
        WHEN 1 THEN
        RETURN QUERY
        SELECT p.id as id, p.tekst as tekst, cast(p.vrsta as int) as vrsta_pitanja, cast(k.predmet_id as varchar) as predmet
        FROM pitanje p CROSS JOIN
            (SELECT predmet_id FROM smjer_predmet
             WHERE predmet_id = pr_id and smjer_id = smj_id) k WHERE p.tip = 1;
        WHEN 3 THEN
            RETURN QUERY
            SELECT p.id as id, p.tekst as tekst, cast(p.vrsta as int) as vrsta_pitanja, cast(k.asistent_id as varchar) as asistent
            FROM pitanje p CROSS JOIN
            (SELECT asistent_id FROM asistent_smjer_predmet WHERE predmet_id = pr_id and smjer_id = smj_id) k WHERE p.tip = 3;
        WHEN 2 THEN
            RETURN QUERY
            SELECT p.id as id, p.tekst as tekst, cast(p.vrsta as int) as vrsta_pitanja, cast(k.profesor_id as varchar) as prof
            FROM pitanje p CROSS JOIN
            (SELECT profesor_id FROM smjer_predmet WHERE predmet_id = pr_id and smjer_id = smj_id) k WHERE p.tip = 2;
        ELSE RAISE 'Pogresna vrsta pitanja';
        END CASE;
    END;
    $$ LANGUAGE plpgsql;
 

CREATE OR REPLACE FUNCTION jmbg_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        tp int := (SELECT p.tip FROM pitanje p WHERE p.id = new.pitanje_id);
        pr_id int := (SELECT predmet_id FROM alias WHERE alias = new.alias);
        smj_id int := (SELECT smjer_id FROM alias WHERE alias = new.alias);
    BEGIN
        CASE tp
            WHEN 2 THEN
            IF (SELECT sp.profesor_id FROM smjer_predmet sp
            WHERE pr_id = sp.predmet_id AND
                  smj_id = sp.smjer_id) <> new.jmbg_predavaca THEN
                RAISE 'Taj profesor ne predaje ovaj predmet!';
            END IF;
            WHEN 3 THEN
            IF (SELECT COUNT(*) FROM asistent_smjer_predmet asp
            WHERE asp.asistent_id = new.jmbg_predavaca AND
                  asp.smjer_id = smj_id AND
                  asp.predmet_id = pr_id) = 0 THEN
                RAISE 'Asistent ne predaje na tom smjeru!';
            end if;
            ELSE
                new.vrijeme = now();
                RETURN NEW;
        END CASE;
        new.vrijeme = now();
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

-- druga verzija   
CREATE OR REPLACE FUNCTION broj_odg()
RETURNS TRIGGER AS
    $$
    DECLARE
        broj_asistenata int := (SELECT COUNT(DISTINCT(asistent_id)) FROM asistent_smjer_predmet WHERE predmet_id = (
                        SELECT predmet_id FROM alias INNER JOIN student_alias sa on alias.alias = sa.alias and sa.alias =
                        (SELECT DISTINCT alias FROM nova_tabela)) and smjer_id =
                        (SELECT smjer_id FROM alias INNER JOIN student_alias sa on alias.alias = sa.alias and sa.alias =
                        (SELECT DISTINCT alias FROM nova_tabela)));
        br int := (SELECT COUNT(DISTINCT n.pitanje_id) FROM nova_tabela n);
        total int := ((SELECT COUNT(*) FROM pitanje p WHERE p.tip = 3) * broj_asistenata) +
                     (SELECT COUNT(*) FROM pitanje p WHERE p.tip <> 3);
    BEGIN
        IF br <> total THEN
            RAISE 'Moraju se unijeti odgovori za sva pitanja!';
        END IF;
        UPDATE student_alias SET popunio = true WHERE alias = (SELECT DISTINCT alias FROM nova_tabela);
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    
    
CREATE OR REPLACE FUNCTION alias_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        al varchar := new.alias;
    BEGIN
        IF (SELECT a.popunio FROM student_alias a WHERE a.alias = al) = true THEN
            RAISE 'Anketa za jedan predmet se popunjava samo jednom!';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
 
 
CREATE OR REPLACE FUNCTION semestar_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        br_sem int := (SELECT br_semestara FROM smjer WHERE id = new.smjer_id);
    BEGIN
        IF new.semestar > br_sem THEN
            RAISE 'Unesite ispravan semestar!';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    
    
CREATE OR REPLACE FUNCTION smjer_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        smj int = (SELECT smjer_id FROM alias WHERE alias = new.alias);
    BEGIN
        IF smj <> (SELECT smjer_id FROM student WHERE student.broj_idx = new.broj_idx) THEN
            RAISE 'Student nije na tom smjeru!';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    
    
CREATE OR REPLACE FUNCTION alias_semestar_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        alias_sem int := (SELECT sp.semestar FROM alias a
                          INNER JOIN smjer_predmet sp ON a.predmet_id = sp.predmet_id
                          AND a.smjer_id = sp.smjer_id AND a.alias = new.alias);

        student_sem int := (SELECT s.semestar FROM student s WHERE s.broj_idx = new.broj_idx);
    BEGIN
        IF abs(student_sem-alias_sem) > 2 or alias_sem > student_sem THEN
            RAISE 'Student trenutno ne sluša taj predmet';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    
    
CREATE OR REPLACE FUNCTION tekst_odg_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        vrsta_pitanja int := (SELECT p.vrsta FROM pitanje p WHERE p.id = new.pitanje_id);
        num bool := (SELECT p.numericko FROM pitanje p WHERE p.id = new.pitanje_id);
    BEGIN
        IF vrsta_pitanja <> 3 THEN
            RAISE 'Odabrano pitanje nije tipa višestrukog odgovora!';
        END IF;
        IF num is true and cast(new.odgovor as int) < 0 THEN
            RAISE 'Pogrešan unos za numeričko pitanje';
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    
    
CREATE OR REPLACE FUNCTION odg_check()
RETURNS TRIGGER AS
    $$
    DECLARE
        vrsta_pitanja int := (SELECT p.vrsta FROM pitanje p WHERE p.id = new.pitanje_id);
    BEGIN
        CASE vrsta_pitanja
            WHEN 1 THEN
                IF lower(new.value) not in  ('da', 'ne') THEN
                    RAISE 'Neispravan odgovor!';
                END IF;
            WHEN 3 THEN
                IF (SELECT COUNT(*) from tekst_odgovor WHERE pitanje_id = new.pitanje_id AND odgovor = new.value) = 0 THEN
                        RAISE 'Neispravan odgovor!, %', new.pitanje_id;
                    END IF;
                ELSE
                    RETURN NEW;
            END CASE;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    
create trigger semestar_trigger
	before insert
	on student
	for each row
	execute procedure semestar_check();
	
create trigger jmbg_check
	before insert
	on pitanje_odgovor
	for each row
	execute procedure jmbg_check();

create trigger je_li_popunjen
	before insert
	on pitanje_odgovor
	for each row
	execute procedure alias_check();
	
CREATE TRIGGER broj_odg 
    AFTER INSERT ON pitanje_odgovor
    REFERENCING NEW TABLE AS nova_tabela
    FOR EACH STATEMENT
    EXECUTE PROCEDURE broj_odg();

create trigger odg_check
	before insert
	on pitanje_odgovor
	for each row
	execute procedure odg_check();

create trigger zabrana_brisanja
	before delete
	on pitanje_odgovor
	for each row
	execute procedure zabrana_brisanja();

create trigger odg_backup
	after insert
	on pitanje_odgovor
	for each row
	execute procedure odg_backup();

create trigger predmet_check
	before insert
	on student_alias
	for each row
	execute procedure provjera_predmeta();

create trigger smjer_check_trigger
	before insert
	on student_alias
	for each row
	execute procedure smjer_check();

create trigger alias_semestar_check
	before insert
	on student_alias
	for each row
	execute procedure alias_semestar_check();

create trigger tekst_odg_check
	before insert
	on tekst_odgovor
	for each row
	execute procedure tekst_odg_check();
    
-- Pomoćna funkcija za funkciju ispod

CREATE OR REPLACE FUNCTION tekstualni_odgovori(aime varchar, aprezime varchar, predmet int, num boolean)
RETURNS TABLE (cnt bigint,odg varchar) AS
    $$
    DECLARE
        ajmbg char(13) := (SELECT a.jmbg FROM asistent a WHERE a.ime = aime AND a.prezime = aprezime);
    BEGIN
        RETURN QUERY (SELECT COUNT(C.odgovor), C.odgovor FROM pitanje p
INNER JOIN
(SELECT value AS odgovor, A.alias AS sifra, B.pid, A.jmbg, A.pitanje_id FROM
    (SELECT odg.value, a.alias, odg.pitanje_id, odg.jmbg_predavaca as jmbg
        FROM pitanje_odgovor odg
        INNER JOIN student_alias a
        ON odg.alias = a.alias
        AND a.popunio IS TRUE
        AND ODG.jmbg_predavaca = ajmbg) A
    INNER JOIN
        (SELECT * FROM alias a
            INNER JOIN
                (SELECT asp.smjer_id, asp.predmet_id as pid, asp.asistent_id
                    FROM smjer_predmet sp
                    INNER JOIN asistent_smjer_predmet asp
                        ON sp.predmet_id = asp.predmet_id
                        AND sp.smjer_id = asp.smjer_id) k
                    ON a.predmet_id = k.pid
                    AND k.pid = predmet
                    AND a.smjer_id = k.smjer_id) B
            ON A.alias = B.alias) C
    ON p.id = C.pitanje_id
    AND p.vrsta = 3
    AND p.numericko = num
    GROUP BY C.odgovor);
    END;
    $$ LANGUAGE plpgsql;

select * from tekstualni_odgovori('Sead', 'Delalić', 24, true);

    
/*
Kreirati proceduru koja za proslijeđeno ime i prezime asistenta i predmeta pregledno
   prikazuje studentske ocjene.
       ○ Za tekstualne odgovore, prikazati sve studentske odgovore.
       ○ Za numeričke ocjene, prikazati prosjek, te broj odgovora za svaku ocjenu.
       ○ Za svako pitanje koje nema numeričku ocjenu, prikazati postotak odgovora za
           svaku ponuđenu opciju (npr. DA 72%).
*/
CREATE OR REPLACE FUNCTION ispis_odgovora(aime varchar, aprezime varchar, predmet int)
RETURNS VOID AS
    $$
    DECLARE
        red record;
        jmbg char(13) := (SELECT a.jmbg FROM asistent a WHERE a.ime = aime AND a.prezime = aprezime);
        prosjek numeric := 0;
        total_text int := (SELECT SUM(r.cnt) FROM (SELECT * FROM tekstualni_odgovori(aime, aprezime, predmet, false))r);
        total_num int := (SELECT SUM(r.cnt) FROM (SELECT * FROM tekstualni_odgovori(aime, aprezime, predmet, true))r);
    BEGIN
        RAISE NOTICE 'Tekstualna pitanja:';
        FOR red IN (SELECT odg.value FROM pitanje_odgovor odg
            INNER JOIN pitanje p ON odg.pitanje_id = p.id
            AND p.vrsta = 2 AND odg.jmbg_predavaca = jmbg) LOOP
            RAISE NOTICE '%', red.value;
        END LOOP;
        RAISE NOTICE '------------------------------';
        RAISE NOTICE 'Numerička pitanja:';
        FOR red IN SELECT * FROM tekstualni_odgovori(aime, aprezime, predmet, true) LOOP
            prosjek := prosjek + (red.cnt*cast(red.odg as int));
            RAISE NOTICE E'%:% %', red.odg, (cast(red.cnt as float)/total_num)*100, '%' ;
        END LOOP;
        RAISE NOTICE 'Prosjek: %', prosjek/(SELECT SUM(r.cnt) FROM tekstualni_odgovori(aime, aprezime, predmet, true) r);
        RAISE NOTICE '------------------------------';
        RAISE NOTICE 'Tekstualna višestruka pitanja:';
        RAISE NOTICE 'TOTAL %', total_text;
        FOR red IN SELECT * FROM tekstualni_odgovori(aime, aprezime, predmet, false) LOOP
            RAISE NOTICE E'%:% %', red.odg, (cast(red.cnt as float)/total_text)*100, '%' ;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    
-- Onemogućiti brisanje studentskih odgovora iz baze podataka (jednom unesen odgovor,
-- ne smije se brisati).
CREATE OR REPLACE FUNCTION zabrana_brisanja()
RETURNS TRIGGER AS
    $$
    BEGIN
       RAISE 'Zabranjeno je brisanje već unesenih odgovora!';
    END;
    $$ LANGUAGE plpgsql;
    
-- Kreirati trigger koji pri insertu odgovora radi unos podataka u backup tabelu (tabelu koja
-- čuva kopiju podataka).
CREATE OR REPLACE FUNCTION odg_backup()
RETURNS TRIGGER AS
    $$
    BEGIN
        INSERT INTO backup_pitanje_odgovor (vrijeme, value, pitanje_id, alias, jmbg_predavaca) VALUES
        (now(), new.value, new.pitanje_id, new.alias, new.jmbg_predavaca);
        RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    
/*
Kreirati proceduru koja za proslijeđeno pitanje vraća poredak profesora i asistenata po
   studentskim ocjenama. Omogućiti da procedura radi samo za pitanja sa numeričkim
   odgovorom, za sva ostala pitanja procedura ispisuje grešku.
*/
CREATE OR REPLACE FUNCTION poredaj_po_ocjeni(pid int)
RETURNS TABLE (pime varchar, pprezime varchar, pocjena int) AS
    $$
    DECLARE
        ptip int := (SELECT p.tip FROM pitanje p WHERE p.id = pid);
    BEGIN
        IF (SELECT numericko FROM pitanje WHERE id = pid) IS FALSE THEN
            RAISE 'Vrsta pitanja mora biti "numeričko"';
        END IF;
        CASE ptip
            WHEN 3 THEN
            RETURN QUERY SELECT ass.ime, ass.prezime, cast(A.value as int) as ocjena FROM
                        (SELECT * FROM pitanje_odgovor odg
                        INNER JOIN pitanje p ON odg.pitanje_id = p.id
                        AND p.id = pid) A INNER JOIN
                        asistent ass ON A.jmbg_predavaca = ass.jmbg
                        ORDER BY ocjena DESC;
            WHEN 2 THEN
            RETURN QUERY SELECT prof.ime, prof.prezime, cast(A.value as int) as ocjena FROM
                        (SELECT * FROM pitanje_odgovor odg
                        INNER JOIN pitanje p ON odg.pitanje_id = p.id
                        AND p.id = pid) A INNER JOIN
                        profesor prof ON A.jmbg_predavaca = prof.jmbg
                        ORDER BY ocjena DESC;
            ELSE RAISE 'Pogrešan TIP pitanja';
        END CASE;
    END;
    $$ LANGUAGE plpgsql;
    
    
-- Kreirati upit koji vraća podatke o profesoru i asistentu sa najboljim prosječnim ocjenama.

SELECT P.profime, P.profprezime, P.profocjena, asis.asime, asis.asprezime, asis.asocjena FROM (
SELECT prof.ime as profime, prof.prezime as profprezime, C.ocjena as profocjena FROM (
    SELECT b.jmbg, b.ocjena FROM (
        SELECT AVG(cast(odg.value as int)) as ocjena, odg.jmbg_predavaca as jmbg FROM pitanje_odgovor odg
        INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.numericko IS TRUE
        AND p.tip = 2
        GROUP BY jmbg) b WHERE ocjena = (
    SELECT MAX(a.ocjena) as ocjena FROM (
        SELECT AVG(cast(odg.value as int)) as ocjena, odg.jmbg_predavaca as jmbg FROM pitanje_odgovor odg
        INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.numericko IS TRUE
        AND p.tip = 2
        GROUP BY jmbg) a)) C
    INNER JOIN profesor prof ON prof.jmbg = C.jmbg) P, (
SELECT ass.ime asime, ass.prezime asprezime, C.ocjena asocjena FROM (
    SELECT b.jmbg, b.ocjena FROM (
        SELECT AVG(cast(odg.value as int)) as ocjena, odg.jmbg_predavaca as jmbg FROM pitanje_odgovor odg
        INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.numericko IS TRUE
        AND p.tip = 3
        GROUP BY jmbg) b WHERE ocjena = (
    SELECT MAX(a.ocjena) as ocjena FROM (
        SELECT AVG(cast(odg.value as int)) as ocjena, odg.jmbg_predavaca as jmbg FROM pitanje_odgovor odg
        INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.numericko IS TRUE
        AND p.tip = 3
        GROUP BY jmbg) a)) C
    INNER JOIN asistent ass ON ass.jmbg = C.jmbg) asis;
    
    
-- Kreirati upit koji vraća podatke o profesoru kojeg je ocijenio najveći broj studenata.

SELECT prof.ime, prof.prezime, prof.datum_rodj FROM (
    SELECT jmbg FROM (
        SELECT COUNT(odg.alias) as broj_odg, odg.jmbg_predavaca as jmbg FROM
        pitanje_odgovor odg INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.tip = 2
        GROUP BY jmbg) A WHERE broj_odg = (SELECT MAX(B.broj_odg) FROM (
        SELECT COUNT(odg.alias) as broj_odg, odg.jmbg_predavaca as jmbg FROM
        pitanje_odgovor odg INNER JOIN pitanje p ON odg.pitanje_id = p.id
        WHERE p.tip = 2
        GROUP BY jmbg) B)) C INNER JOIN profesor prof
    ON prof.jmbg = C.jmbg;
    
    
-- Kreirati upit koji vraća predmet sa najvećim brojem studenata.

SELECT pr.id, pr.naziv, pr.br_sati_sedmicno FROM (
    SELECT predmet_id FROM (
        SELECT COUNT(a.predmet_id) as br_studenata, a.predmet_id
        FROM student_alias sa
        INNER JOIN alias a ON sa.alias = a.alias
        GROUP BY predmet_id) A WHERE br_studenata = (SELECT MAX(B.br_studenata) FROM(
        SELECT COUNT(a.predmet_id) as br_studenata, a.predmet_id
        FROM student_alias sa
        INNER JOIN alias a ON sa.alias = a.alias
        GROUP BY predmet_id) B)) C INNER JOIN predmet pr
    ON C.predmet_id = pr.id;
    
    
-- Kreirati ​view ​koji sadrži podatke o profesoru, predmetu i tekstualnim odgovorima.


CREATE VIEW predmet_profesor_odgovori AS
    SELECT prof.ime || ' ' || prof.prezime as ime, prof.datum_rodj, E.naziv, E.semestar,
           E.br_sati_sedmicno,
           E.izborni, E.tekst as pitanje, E.value as odgovor
    FROM profesor prof INNER JOIN (
        SELECT pr.naziv, pr.br_sati_sedmicno, D.predmet_id, D.value, D.semestar, D.ects, D.izborni, D.jmbg_predavaca, D.tekst
        FROM predmet pr INNER JOIN (
            SELECT C.predmet_id, C.value, sp.semestar, sp.ects, sp.izborni, C.jmbg_predavaca, C.tekst
            FROM smjer_predmet sp INNER JOIN (
                SELECT a.predmet_id, B.alias, B.jmbg_predavaca, B.value, B.tekst FROM (
                    SELECT odg.alias, odg.jmbg_predavaca, odg.value, p.tekst FROM pitanje_odgovor odg
                    INNER JOIN pitanje p
                    ON odg.pitanje_id = p.id
                    AND p.tip = 2) B
                INNER JOIN alias a
                ON B.alias = a.alias) C
            ON C.predmet_id = sp.predmet_id) D
        ON D.predmet_id = pr.id) E
    ON E.jmbg_predavaca = prof.jmbg;
