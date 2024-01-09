set @active_datetime := (Select max(active_datetime) from prod_db_3.activemus) ;
SET SQL_SAFE_UPDATES = 0 ;

drop temporary table  if exists tempdb.agent_model_id;
Create temporary table tempdb.agent_model_id
SELECT agent_diagonal_model_id, mus_name FROM prod_db_3.mus
where mus_id in (Select distinct mus_id from prod_db_3.activemus 
							where active_datetime = @active_datetime)
						and mus_name not like '%telco_france_Care%' and mus_name not like '%root_mu%' and mus_name not like '%catch-all-mu%'
                        and mus_name not like '%Retention%' and mus_name in ('telco_france_Fixe','telco_france_FTTH','telco_france_Mobile');


drop temporary table if exists tempdb.agent_perf_table;
create temporary table tempdb.agent_perf_table
select agent_diagonal_model_id, agent_id, agent_percentile 
from 
prod_db_3.agent_diagonal_model
where agent_diagonal_model_id in 
(select agent_diagonal_model_id 
from 
tempdb.agent_model_id) ;

drop temporary table if exists tempdb.agent_model_table_joined;
create temporary table tempdb.agent_model_table_joined
select a.*, b.agent_id, b.agent_percentile
from tempdb.agent_model_id a
left join 
tempdb.agent_perf_table b
on a.agent_diagonal_model_id = b.agent_diagonal_model_id ;


drop temporary table if exists tempdb.joinwithvdns;
create temporary table tempdb.joinwithvdns
select a.*, b.*, (case when a.mus_name = 'telco_france_FTTH' then 'FTTH'  
 when a.mus_name = 'telco_france_Fixe' then 'NonFTTH_Fixe' 
  when a.mus_name = 'telco_france_Mobile' then 'NonFTTH_Mobile' end)
 as MAP  from tempdb.agent_model_table_joined a
 left join prod_db_3.model_maps b
 on a.mus_name = b.model_name ;
 
 drop temporary table if exists tempdb.agent_skilling_Fixe;
 create temporary table tempdb.agent_skilling_Fixe
 select agentid, skill as rank_fixe, 'FixeFTTH' as type_skill 
 from telco_francesatmap.`bygs_sales.agent_skilling`   #change required if on AI server
 where type_skill = 'NonFTTH_Fixe';
 
  drop temporary table if exists tempdb.agent_skilling_Mobile;
 create temporary table tempdb.agent_skilling_Mobile
 select agentid, skill as rank_mobile, 'MobileFTTH' as type_skill
 from telco_francesatmap.`bygs_sales.agent_skilling`   #change required if on AI server
 where type_skill = 'NonFTTH_Mobile' ;
 
drop temporary table if exists tempdb.agent_perf_2 ;
create temporary table tempdb.agent_perf_2
 select a.*, b.type_skill, b.skill
 from tempdb.joinwithvdns a
 left join telco_francesatmap.`bygs_sales.agent_skilling` b   #change required if on AI server
 on a.agent_id = b.agentid and a.MAP = b.type_skill ;

UPDATE tempdb.agent_perf_2 
SET type_skill = 'MobileFTTH'
WHERE type_skill is NULL and  VDN in (1028,1029,1051,1052,1055,1056,1059,1060,11028,11029,11051,11052,11055,11056,11059,11060);

UPDATE tempdb.agent_perf_2 
SET type_skill = 'FixeFTTH'
WHERE type_skill is NULL
and MAP = 'FTTH'
;

UPDATE tempdb.agent_perf_2 a
LEFT JOIN tempdb.agent_skilling_Mobile as  b
ON a.agent_id=b.agentid and a.type_skill = b.type_skill
set a.skill = b.rank_mobile
WHERE a.skill is NULL and  a.MAP='FTTH' and a.VDN in (1028,1029,1051,1052,1055,1056,1059,1060,11028,11029,11051,11052,11055,11056,11059,11060) and a.type_skill = 'MobileFTTH' ;

UPDATE tempdb.agent_perf_2 a
LEFT JOIN tempdb.agent_skilling_Fixe as  b
ON a.agent_id=b.agentid and a.type_skill = b.type_skill
set a.skill = b.rank_fixe
WHERE a.skill is NULL and  a.MAP='FTTH' and a.VDN not in (1028,1029,1051,1052,1055,1056,1059,1060,11028,11029,11051,11052,11055,11056,11059,11060) and a.type_skill = 'FixeFTTH';

drop temporary table if exists tempdb.vp_fixe_mobile ;
create temporary table tempdb.vp_fixe_mobile
SELECT * ,
CASE 
   when agent_percentile between 0.8 and 1.0 and SKILL = 'OR_FIXE' and MAP= 'NonFTTH_Fixe'  then 0 
  when agent_percentile between 0.8 and 1.0 and SKILL = 'ARGENT_FIXE' and MAP= 'NonFTTH_Fixe'  then 0
  when agent_percentile between 0.8 and 1.0 and SKILL = 'METAL_FIXE' and MAP= 'NonFTTH_Fixe'  then 0

  when agent_percentile between 0.5 and 0.8 and SKILL = 'OR_FIXE' and MAP= 'NonFTTH_Fixe'  then 0
  when agent_percentile between 0.5 and 0.8 and SKILL = 'ARGENT_FIXE' and MAP= 'NonFTTH_Fixe'  then 1
  when agent_percentile between 0.5 and 0.8 and SKILL = 'METAL_FIXE' and MAP= 'NonFTTH_Fixe'  then 1

  when agent_percentile between 0.3 and 0.5 and SKILL = 'OR_FIXE' and MAP= 'NonFTTH_Fixe'  then 1
  when agent_percentile between 0.3 and 0.5 and SKILL = 'ARGENT_FIXE' and MAP= 'NonFTTH_Fixe'  then 2
  when agent_percentile between 0.3 and 0.5 and SKILL = 'METAL_FIXE' and MAP= 'NonFTTH_Fixe'  then 2

  when agent_percentile between 0.0 and 0.3 and SKILL = 'OR_FIXE' and MAP= 'NonFTTH_Fixe'  then 2
  when agent_percentile between 0.0 and 0.3 and SKILL = 'ARGENT_FIXE' and MAP= 'NonFTTH_Fixe'  then 3
  when agent_percentile between 0.0 and 0.3 and SKILL = 'METAL_FIXE' and MAP= 'NonFTTH_Fixe'  then 3

  when agent_percentile between 0.7 and 1.0 and SKILL = 'OR_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 0
  when agent_percentile between 0.7 and 1.0 and SKILL = 'ARGENT_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 0
  when agent_percentile between 0.7 and 1.0 and SKILL = 'METAL_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 1

  when agent_percentile between 0.5 and 0.7 and SKILL = 'OR_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 1
  when agent_percentile between 0.5 and 0.7 and SKILL = 'ARGENT_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 1
  when agent_percentile between 0.5 and 0.7 and SKILL = 'METAL_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 2

  when agent_percentile between 0.3 and 0.5 and SKILL = 'OR_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 2 
  when agent_percentile between 0.3 and 0.5 and SKILL = 'ARGENT_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 3
  when agent_percentile between 0.3 and 0.5 and SKILL = 'METAL_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 4

  when agent_percentile between 0.0 and 0.3 and SKILL = 'OR_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 3
  when agent_percentile between 0.0 and 0.3 and SKILL = 'ARGENT_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 4 
  when agent_percentile between 0.0 and 0.3 and SKILL = 'METAL_MOBILE' and MAP= 'NonFTTH_MOBILE'  then 5
  
   when agent_percentile between 0.0 and 0.3 and SKILL = 'TLV_FTTH' and MAP= 'FTTH'  then 3
  when agent_percentile between 0.3 and 0.5 and SKILL = 'TLV_FTTH' and MAP= 'FTTH'  then 2
  when agent_percentile between 0.5 and 0.7 and SKILL = 'TLV_FTTH' and MAP= 'FTTH'  then 1
  when agent_percentile between 0.7 and 1.0 and SKILL = 'TLV_FTTH' and MAP= 'FTTH'  then 0 
  
  when agent_percentile between 0.0 and 0.3 and SKILL = 'OR_FIXE' and MAP= 'FTTH'  then 3
  when agent_percentile between 0.3 and 0.5 and SKILL = 'OR_FIXE' and MAP= 'FTTH'  then 2 
  when agent_percentile between 0.5 and 0.7 and SKILL = 'OR_FIXE' and MAP= 'FTTH'  then 1
  when agent_percentile between 0.7 and 1.0 and SKILL = 'OR_FIXE' and MAP= 'FTTH'  then 0 
    
  when agent_percentile between 0.0 and 0.3 and SKILL = 'ARGENT_FIXE' and MAP= 'FTTH'  then 4
  when agent_percentile between 0.3 and 0.5 and SKILL = 'ARGENT_FIXE' and MAP= 'FTTH'  then 3 
  when agent_percentile between 0.5 and 0.7 and SKILL = 'ARGENT_FIXE' and MAP= 'FTTH'  then 2 
  when agent_percentile between 0.7 and 1.0 and SKILL = 'ARGENT_FIXE' and MAP= 'FTTH'  then 0 
  
  when agent_percentile between 0.0 and 0.3 and SKILL = 'METAL_FIXE' and MAP= 'FTTH'  then 5
  when agent_percentile between 0.3 and 0.5 and SKILL = 'METAL_FIXE' and MAP= 'FTTH'  then 4 
  when agent_percentile between 0.5 and 0.7 and SKILL = 'METAL_FIXE' and MAP= 'FTTH'  then 3 
  when agent_percentile between 0.7 and 1.0 and SKILL = 'METAL_FIXE' and MAP= 'FTTH'  then 0
    
  when agent_percentile between 0.0 and 0.3 and SKILL = 'OR_MOBILE' and MAP= 'FTTH'  then 3
  when agent_percentile between 0.3 and 0.5 and SKILL = 'OR_MOBILE' and MAP= 'FTTH'  then 2
  when agent_percentile between 0.5 and 0.7 and SKILL = 'OR_MOBILE' and MAP= 'FTTH'  then 1  
  when agent_percentile between 0.7 and 1.0 and SKILL = 'OR_MOBILE' and MAP= 'FTTH'  then 0 
  
  when agent_percentile between 0.0 and 0.3 and SKILL = 'ARGENT_MOBILE' and MAP= 'FTTH'  then 4
  when agent_percentile between 0.3 and 0.5 and SKILL = 'ARGENT_MOBILE' and MAP= 'FTTH'  then 3
  when agent_percentile between 0.5 and 0.7 and SKILL = 'ARGENT_MOBILE' and MAP= 'FTTH'  then 2
  when agent_percentile between 0.7 and 1.0 and SKILL = 'ARGENT_MOBILE' and MAP= 'FTTH'  then 0 
  
  when agent_percentile between 0.0 and 0.3 and SKILL = 'METAL_MOBILE' and MAP= 'FTTH'  then 5
  when agent_percentile between 0.3 and 0.5 and SKILL = 'METAL_MOBILE' and MAP= 'FTTH'  then 4
  when agent_percentile between 0.5 and 0.7 and SKILL = 'METAL_MOBILE' and MAP= 'FTTH'  then 3
  when agent_percentile between 0.7 and 1.0 and SKILL = 'METAL_MOBILE' and MAP= 'FTTH'  then 0

END as Priority

FROM tempdb.agent_perf_2  ;


/**select * from telco_francesatmap.`bygs_sales.agent_skilling` where agentid in (
select distinct(agent_id) from tempdb.vp_fixe_mobile
where priority is null );#Check
**/

ALTER TABLE tempdb.vp_fixe_mobile ADD INDEX `agent_id1` (`agent_id`, `vdn`);

## updating those who are present in agent_performance but not in skilling (can only occur if you have agents which are very old in training data and now they are not in skilling) ##

update tempdb.vp_fixe_mobile
 set Priority = 0 where Priority is null
 and agent_percentile  between 0.7 and 1.0 ;
 
update tempdb.vp_fixe_mobile
set Priority = 1 where Priority is null
and agent_percentile  between 0.5 and 0.7 ;
 
update tempdb.vp_fixe_mobile
set Priority = 3 where Priority is null
and agent_percentile  between 0 and 0.5 ;

## updating those who are present in skilling but not in agent_performance (unknown Agents) ##

drop temporary table if exists tempdb.`agents_not_in_ag_perf`;
create temporary table tempdb.`agents_not_in_ag_perf`
select *, (case when type_skill = 'FTTH' then 'telco_france_FTTH'  
 when type_skill = 'NonFTTH_Fixe' then 'telco_france_Fixe' 
 when type_skill = 'NonFTTH_Mobile' then 'telco_france_Mobile' end)
 as MAP , null as priority
 from telco_francesatmap.`bygs_sales.agent_skilling` 
 where agentid not in (select distinct(agent_id) from tempdb.vp_fixe_mobile)
 and agentid like '4%'
 and agentid in (select distinct agent_id_string from prod_db_3.eval_summary where call_time>adddate(curdate(),-5) and sensor_key='TLS' and unknown_agent=1);
 
## Joining them which their respective model vdns and making all possible combinations ##

 
drop temporary table if exists tempdb.`agents_not_in_ag_perf_2`;
create temporary table tempdb.`agents_not_in_ag_perf_2`
select agentid,type_skill,skill,vdn
from tempdb.`agents_not_in_ag_perf` a
left join prod_db_3.model_maps b
on a.MAP = b.model_name  group by 1,2,3,4;


ALTER TABLE tempdb.`agents_not_in_ag_perf_2` ADD INDEX `agent_id1` (`agentid`, `vdn`);

## Creating Priorities of unknown agents on the basis of skills ##

drop temporary table if exists tempdb.`unk_agents`;
create temporary table tempdb.`unk_agents`
select *,
case 
  when skill = 'TLV_FTTH' and type_skill= 'FTTH'  then 1

  when  skill = 'OR_MOBILE' and type_skill= 'NonFTTH_Mobile' then 1
  when  skill = 'ARGENT_MOBILE' and type_skill= 'NonFTTH_Mobile' then 2
  when  skill = 'METAL_MOBILE' and type_skill= 'NonFTTH_Mobile' then 3
  
  when  skill = 'OR_FIXE' and type_skill= 'NonFTTH_Fixe' then 1
  when  skill = 'ARGENT_FIXE' and type_skill= 'NonFTTH_Fixe' then 2
  when  skill = 'METAL_FIXE' and type_skill= 'NonFTTH_Fixe' then 3
END as Priority
from tempdb.`agents_not_in_ag_perf_2` group by 1,2,3,4,5;

 ALTER TABLE tempdb.`unk_agents` ADD INDEX `agent_id1` (`agentid`, `vdn`);

drop temporary table if exists tempdb.`unk_agents_2`;
create temporary table tempdb.`unk_agents_2`
select agentid as agent_id,vdn,min(Priority) as priority from tempdb.`unk_agents` group by 1,2;

ALTER TABLE tempdb.`unk_agents_2` ADD INDEX `agent_id1` (`agent_id`, `vdn`);


## Creating temp table for agent info ##

drop temporary table if exists tempdb.`agent_info`;
create temporary table tempdb.`agent_info`
select agent_id, null as agent_group,priority as virtual_priority, @active_datetime   as active_datetime,  'default' as evaluator_instance,  vdn
from tempdb.vp_fixe_mobile
union
select  agent_id, null as agent_group,priority as virtual_priority, @active_datetime   as active_datetime,  'default' as evaluator_instance,  vdn
from tempdb.`unk_agents_2`;


ALTER TABLE tempdb.`agent_info`ADD INDEX `agent_id1` (`agent_id`, `vdn`) ;

#SELECT agent_id,vdn,count(*) FROM tempdb.agent_info where vdn is  not null group by 1,2;
#SELECT * FROM tempdb.agent_info where vdn is  not null;


 delete from prod_db_3.`agent_info` where vdn is not null ;
 insert into prod_db_3.`agent_info`
 (select *
 from tempdb.`agent_info` ) ;

delete from prod_db_3.`agent_info`
where agent_id = "-1" and vdn is not null;
delete from prod_db_3.`agent_info`
where agent_id = "!" and vdn is not null;
