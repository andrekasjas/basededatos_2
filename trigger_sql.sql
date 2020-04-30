drop trigger if exists matxest_rr on matxest;
drop trigger if exists materia_rr on materia;
drop trigger if exists docente_rr on docente;
drop trigger if exists doc_cal on docente;
drop table if exists docxmat;
drop table if exists matxest;
drop table if exists docente;
drop table if exists facultad;
drop table if exists materia;
drop table if exists distancia;
drop table if exists presencia;
drop table if exists estudiante;


create table facultad(
fac_id int4,
fac_nom varchar(60) not null,
primary key (fac_id));

create table docente(
doc_id int4,
doc_nom varchar(60) not null,
doc_ape varchar(60) not null,
doc_salbase int8 not null,
descuento int8,
doc_total int8,
doc_fac_id int4 not null,
primary key (doc_id),
foreign key (doc_fac_id) references facultad(fac_id),
check (doc_salbase>0));

create table materia(
mat_id int4,
mat_nom varchar(60) not null,
mat_cre int2 not null,
mat_dep int4,
primary key (mat_id),
check(mat_cre between 0 and 5));

create table docxmat(
dxm_doc_id int4,
dxm_mat_id int4,
primary key(dxm_doc_id,dxm_mat_id),
foreign key (dxm_doc_id) references docente(doc_id),
foreign key (dxm_mat_id) references materia(mat_id));

create table estudiante(
est_id int4,
est_nom varchar(30) not null ,
est_fech date not null,
est_est int2,
primary key (est_id));

create table distancia(
usuario varchar(30),
contra varchar(30),
primary key(usuario))
inherits(estudiante);


create table presencia(
sede varchar(30),
primary key (sede))
inherits(estudiante);

create table matxest(
mxe_mat_id int4,
mxe_est_id int4,
mxe_nota float4 not null,
primary key (mxe_mat_id,mxe_est_id),
foreign key (mxe_mat_id) references materia(mat_id),
foreign key (mxe_est_id) references estudiante(est_id),
check (mxe_nota between 0 and 5)
);

--REGISTRO DE auditoriaORIA--

CREATE schema if not exists auditoria;

REVOKE CREATE ON schema auditoria FROM public;
 
CREATE TABLE if not exists auditoria.logged_actions (
    schema_name text NOT NULL,
    TABLE_NAME text NOT NULL,
    user_name text,
    action_tstamp TIMESTAMP WITH TIME zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    action TEXT NOT NULL CHECK (action IN ('I','D','U')),
    original_data text,
    new_data text
) WITH (fillfactor=100);
 
REVOKE ALL ON auditoria.logged_actions FROM public; 



GRANT SELECT ON auditoria.logged_actions TO public;
 
CREATE INDEX if not exists logged_actions_schema_table_idx 
ON auditoria.logged_actions(((schema_name||'.'||TABLE_NAME)::TEXT));
 
CREATE INDEX if not exists logged_actions_action_tstamp_idx 
ON auditoria.logged_actions(action_tstamp);
 
CREATE INDEX if not exists logged_actions_action_idx 
ON auditoria.logged_actions(action);




CREATE OR REPLACE FUNCTION auditoria.if_modified_func() RETURNS TRIGGER AS $body$
DECLARE
    v_old_data TEXT;
    v_new_data TEXT;
BEGIN
 
    IF (TG_OP = 'UPDATE') THEN
        v_old_data := ROW(OLD.*);
        v_new_data := ROW(NEW.*);
        INSERT INTO auditoria.logged_actions (schema_name,table_name,user_name,action,original_data,new_data) 
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data,v_new_data);
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        v_old_data := ROW(OLD.*);
        INSERT INTO auditoria.logged_actions (schema_name,table_name,user_name,action,original_data)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_old_data);
        RETURN OLD;
    ELSIF (TG_OP = 'INSERT') THEN
        v_new_data := ROW(NEW.*);
        INSERT INTO auditoria.logged_actions (schema_name,table_name,user_name,action,new_data)
        VALUES (TG_TABLE_SCHEMA::TEXT,TG_TABLE_NAME::TEXT,session_user::TEXT,substring(TG_OP,1,1),v_new_data);
        RETURN NEW;
    ELSE
        RAISE WARNING '[auditoria.IF_MODIFIED_FUNC] - Other action occurred: %, at %',TG_OP,now();
        RETURN NULL;
    END IF;
 
EXCEPTION
    WHEN data_exception THEN
        RAISE WARNING '[auditoria.IF_MODIFIED_FUNC] - UDF ERROR [DATA EXCEPTION] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN unique_violation THEN
        RAISE WARNING '[auditoria.IF_MODIFIED_FUNC] - UDF ERROR [UNIQUE] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
    WHEN OTHERS THEN
        RAISE WARNING '[auditoria.IF_MODIFIED_FUNC] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
        RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auditoria;


CREATE TRIGGER facul_da AFTER INSERT OR UPDATE OR DELETE ON facultad FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER doc_da AFTER INSERT OR UPDATE OR DELETE ON docente FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER mat_da AFTER INSERT OR UPDATE OR DELETE ON materia FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER docxmar_da AFTER INSERT OR UPDATE OR DELETE ON docxmat FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER est_da AFTER INSERT OR UPDATE OR DELETE ON estudiante FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();
CREATE TRIGGER matxest_da AFTER INSERT OR UPDATE OR DELETE ON matxest FOR EACH ROW EXECUTE PROCEDURE auditoria.if_modified_func();



-- DISPARADORES --

CREATE OR REPLACE FUNCTION docente_err() returns trigger as
$$
    begin
	if(new.doc_id = null) then
		raise exception 'El id del docente no puede ser nulo';
	end if;
	if(new.doc_salbase<0)then
		raise exception 'El salbaseario no puede ser menor a 0';
	end if;
	if(exists(select * from docente where doc_id=new.doc_id)) then
		raise exception 'El docente ya se encuentra registrado';
	end if;
	if(not exists (select * from facultad where fac_id=new.doc_fac_id))then
		raise exception 'La facultad que esta intentando ingresar no existe';
	end if;
	RETURN NEW;
    end;
$$
LANGUAGE 'plpgsql';
CREATE TRIGGER docente_rr BEFORE INSERT ON docente FOR EACH ROW EXECUTE PROCEDURE docente_err();



CREATE OR REPLACE FUNCTION materia_err() returns trigger as
$$
    begin
	if(new.mat_id = null) then
		raise exception 'El id de la materia no puede ser nulo';
	end if;
	if(exists(select * from materia where mat_id=new.mat_id)) then
		raise exception 'La materia ya se encuentra registrada';
	end if;
	if(exists(select * from materia where mat_nom=new.mat_nom)) then
		raise exception 'Ya se encuentra registrada una materia con el mismo nombre';
	end if;
	
	if(''=new.mat_nom or new.mat_id=null) then
		raise exception 'El nombre o id de la materia no puede estar vacio';
	end if;
	if(new.mat_cre < 0)then
		raise exception 'Los creditos de la materia no pueden ser negativos';
	end if;
	RETURN NEW;
    end;
$$
LANGUAGE 'plpgsql';
CREATE TRIGGER materia_rr BEFORE INSERT ON materia FOR EACH ROW EXECUTE PROCEDURE materia_err();



CREATE OR REPLACE FUNCTION matxest_err() returns trigger as
$$
    begin
	if(not exists (select * from materia where mat_id=new.mxe_mat_id))then
		raise exception 'La materia que esta intentando ingresar no existe';
	end if;
	if(not exists (select * from estudiante where est_id=new.mxe_est_id))then
		raise exception 'El estudiante que esta intentando ingresar no existe';
	end if;
	if(new.mxe_nota<0)then
		raise exception 'La nota del estudiante no puede ser inferior a 0';
	end if;
	if(new.mxe_nota>5)then
		raise exception 'La nota del estudiante no puede ser superior a 5';
	end if;
	if(exists(select * from matxest where mxe_mat_id=new.mxe_mat_id and mxe_est_id=new.mxe_est_id)) then
		raise exception 'La nota del estudiante ya se encuentra registrada';
	end if;
	RETURN NEW;
    end;
$$
LANGUAGE 'plpgsql';
CREATE TRIGGER matxesta_rr BEFORE INSERT ON matxest FOR EACH ROW EXECUTE PROCEDURE matxest_err();

--DISPARADOR CALCULO ARITMETICO (CON EL SALARIO BASE CALCULA EL TOTAL QUITANDOLE 4% DE SALUD Y 4% PARA PENSION)--
CREATE OR REPLACE FUNCTION doc_cal() returns trigger as
$$	
    begin
       update docente set descuento=(doc_salbase*0.08);
       update docente set doc_total=doc_salbase-(doc_salbase*0.08);
       return new;
    end;
$$
LANGUAGE 'plpgsql';
drop trigger if exists doc_cal on docente;
CREATE TRIGGER doc_cal after insert ON docente FOR EACH ROW EXECUTE PROCEDURE  doc_cal();

insert into facultad(fac_id,fac_nom) values(1,'ingenieria de los mancos');
insert into facultad(fac_id,fac_nom) values(2,'salbaseud');
insert into facultad(fac_id,fac_nom) values(3,'ciencias basicas');
insert into facultad(fac_id,fac_nom) values(4,'matematicas');

select * from docente;

insert into docente(doc_id,doc_nom,doc_ape,doc_salbase,doc_fac_id)values(1,'sandra','gomez',1200000,2);
insert into docente(doc_id,doc_nom,doc_ape,doc_salbase,doc_fac_id)values(2,'carlos alberto','vera',1000000,4);
insert into docente(doc_id,doc_nom,doc_ape,doc_salbase,doc_fac_id)values(3,'albaro','carrillo',1500000,1);
insert into docente(doc_id,doc_nom,doc_ape,doc_salbase,doc_fac_id)values(4,'liliana','mora',1400000,3);
insert into docente(doc_id,doc_nom,doc_ape,doc_salbase,doc_fac_id)values(7,'sofia','mora',1400000,1);

insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (1,'calculo diferencial',4,null);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (2,'calculo integral',4,1);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (3,'calculo multi',4,2);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (5,'ecuaciones diferenciales',4,3);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (6,'matematicas especiales',3,5);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (7,'estadistica ||',3,5);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (8,'ingenieria de proyectos',2,7);
insert into materia(mat_id,mat_nom,mat_cre,mat_dep) values (9,'metodologia de la invertigacion',2,8);

insert into estudiante(est_id,est_nom,est_fech) values(13,'andres','19/11/2000');
insert into estudiante(est_id,est_nom,est_fech) values(24,'alexis','12/08/1998');
insert into estudiante(est_id,est_nom,est_fech) values(35,'dayana','08/11/1999');
insert into estudiante(est_id,est_nom,est_fech) values(46,'cristian','11/04/2005');
insert into estudiante(est_id,est_nom,est_fech) values(57,'karol','01/01/2001');
insert into estudiante(est_id,est_nom,est_fech) values(68,'nicky','19/11/2000');

insert into distancia(usuario,contra,est_id,est_nom,est_fech) values('andres','as',1,'d','19/11/2000');
insert into distancia(usuario,contra,est_id,est_nom,est_fech) values('','as',2,'dd','19/11/2000');
insert into distancia(usuario,contra,est_id,est_nom,est_fech) values('fd','as',3,'ddd','19/11/2000');
insert into distancia(usuario,contra,est_id,est_nom,est_fech) values('asd','as',4,'dddd','19/11/2000');

insert into presencia(sede,est_id,est_nom,est_fech) values('casa',5,'p','19/11/2000');
insert into presencia(sede,est_id,est_nom,est_fech) values('poso',6,'pp','19/11/2000');
insert into presencia(sede,est_id,est_nom,est_fech) values('chahc',7,'ppp','19/11/2000');
insert into presencia(sede,est_id,est_nom,est_fech) values('asdd',8,'pppp','19/11/2000');

insert into docxmat(dxm_doc_id,dxm_mat_id) values(1,1);
insert into docxmat(dxm_doc_id,dxm_mat_id) values(2,2);
insert into docxmat(dxm_doc_id,dxm_mat_id) values(3,3);
insert into docxmat(dxm_doc_id,dxm_mat_id) values(3,5);

insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(24,2,2.9);
insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(57,1,3.6);
insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(68,5,3.1);
insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(13,6,3.9);
insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(24,5,3.0);
insert into matxest(mxe_est_id,mxe_mat_id,mxe_nota ) values(24,8,3.6);

select *
from auditoria.logged_actions;

select *
from docente