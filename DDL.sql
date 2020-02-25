create table alias
(
    predmet_id integer not null,
    smjer_id   integer not null,
    alias      char(9) not null
        constraint alias_pkey
            primary key,
    constraint smjer_predmet_fkey
        foreign key (predmet_id, smjer_id) references smjer_predmet
            on update restrict on delete restrict
);

create table asistent
(
    jmbg          char(13)              not null
        constraint asistent_pkey
            primary key
        constraint jbmg_check
            check (length(jmbg) = 13),
    ime           varchar(40)           not null,
    prezime       varchar(40)           not null,
    datum_rodj    date                  not null,
    visi_asistent boolean default false not null
);

create table asistent_smjer_predmet
(
    asistent_id char(13)
        constraint asistent_smjer_predmet_asistent_id_fkey
            references asistent
            on update restrict on delete restrict,
    predmet_id  integer,
    smjer_id    integer,
    constraint asistent_smjer_predmet_predmet_id_fkey
        foreign key (predmet_id, smjer_id) references smjer_predmet
            on update restrict on delete restrict
);

create table backup_pitanje_odgovor
(
    vrijeme        timestamp,
    value          varchar(500) not null,
    pitanje_id     integer      not null,
    alias          char(9)      not null,
    jmbg_predavaca char(13)
);


create table dr_klasifikacija
(
    rank  smallint    not null
        constraint dr_klasifikacija_pkey
            primary key
        constraint br_rankova
            check ((rank > 0) AND (rank < 6)),
    naziv varchar(30) not null
);

create table drzava
(
    id    smallint     not null
        constraint drzava_pkey
            primary key,
    naziv varchar(100) not null
);

create table grad
(
    id     smallint     not null
        constraint grad_pkey
            primary key,
    ime    varchar(100) not null,
    drzava smallint
        constraint fk_grad_drzava_1
            references drzava
);

create table odsjek
(
    id    serial       not null
        constraint odsjek_pkey
            primary key,
    naziv varchar(150) not null
        constraint odsjek_naziv_key
            unique
);


create table pitanje
(
    id        serial                not null
        constraint pitanje_pkey
            primary key,
    tekst     varchar(300)          not null,
    vrsta     smallint              not null
        constraint pitanje_vrsta_fkey
            references pitanje_vrsta
            on update cascade on delete restrict,
    tip       smallint              not null
        constraint pitanje_tip_fkey
            references pitanje_tip
            on update cascade on delete restrict,
    numericko boolean default false not null,
    constraint num_check
        check (CASE WHEN (numericko IS TRUE) THEN (vrsta = 3) ELSE NULL::boolean END)
);

create table pitanje_odgovor
(
    vrijeme        timestamp,
    value          varchar(500) not null,
    pitanje_id     integer      not null
        constraint fkey_pitanje
            references pitanje
            on update cascade on delete restrict,
    alias          char(9)      not null
        constraint student_alias_fkey
            references student_alias (alias)
            on update restrict on delete restrict,
    jmbg_predavaca char(13)
);

create table pitanje_tip
(
    id  smallint    not null
        constraint pitanje_tip_pkey
            primary key
        constraint minmax_id
            check ((id > 0) AND (id < 4)),
    tip varchar(30) not null
);

create table pitanje_vrsta
(
    id    smallint    not null
        constraint pitanje_vrsta_pkey
            primary key
        constraint minmax_vrsta
            check ((id > 0) AND (id < 4)),
    vrsta varchar(30) not null
);

create table predmet
(
    id               serial       not null
        constraint predmet_pkey
            primary key,
    naziv            varchar(100) not null,
    br_sati_sedmicno smallint     not null
);

create table profesor
(
    jmbg       char(13)    not null
        constraint profesor_pkey
            primary key
        constraint jbmg_check
            check (length(jmbg) = 13),
    ime        varchar(40) not null,
    prezime    varchar(40) not null,
    datum_rodj date        not null,
    rank       smallint
        constraint profesor_rank_fkey
            references dr_klasifikacija
            on update cascade on delete restrict
);

create table smjer
(
    id           serial       not null
        constraint smjer_pkey
            primary key,
    br_semestara smallint     not null
        constraint min_br_semestara
            check ((br_semestara < 13) AND (br_semestara > 0)),
    odsjek_id    integer
        constraint smjer_odsjek_id_fkey
            references odsjek,
    naziv        varchar(100) not null
);

create table smjer_predmet
(
    predmet_id  integer               not null
        constraint smjer_predmet_predmet_id_fkey
            references predmet
            on update cascade on delete restrict,
    smjer_id    integer               not null
        constraint smjer_predmet_smjer_id_fkey
            references smjer
            on update cascade on delete restrict,
    semestar    smallint              not null
        constraint minmax_semestar
            check ((semestar > 0) AND (semestar < 13)),
    izborni     boolean default false not null,
    ects        smallint              not null
        constraint minmax_ects
            check ((ects > 0) AND (ects < 21)),
    profesor_id char(13)              not null
        constraint smjer_predmet_profesor_id_fkey
            references profesor
            on update restrict on delete restrict,
    constraint smjer_predmet_pkey
        primary key (predmet_id, smjer_id)
);

create table student
(
    ime        varchar(50) not null,
    prezime    varchar(50) not null,
    broj_idx   varchar(10) not null
        constraint student_pk
            primary key,
    datum_rodj date        not null,
    smjer_id   integer
        constraint smjer_fkey
            references smjer,
    semestar   smallint,
    grad       integer
        constraint grad_fkey
            references grad
            on update cascade on delete restrict
);

create table student_alias
(
    alias    char(9)
        constraint student_alias_alias_key
            unique
        constraint student_alias_alias_fkey
            references alias
            on update restrict on delete restrict,
    broj_idx varchar(10)
        constraint student_alias_broj_idx_fkey
            references student
            on update restrict on delete set null,
    popunio  boolean default false not null
);

create table tekst_odgovor
(
    pitanje_id integer
        constraint tekst_odgovor_pitanje_id_fkey
            references pitanje
            on update cascade on delete cascade,
    odgovor    varchar(15) not null
);

