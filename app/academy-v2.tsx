"use client";

import { useEffect, useMemo, useState } from "react";
import { createClient } from "@supabase/supabase-js";

type Chapter = { title:string; body:string; example?:string; callout?:string };
type Media = { type:string; kind?:string; title:string; url?:string; source?:string };
type Quiz = { question:string; choices:string[]; answer:number; explanation:string };
type Course = {
  id:string; slug:string; title:string; summary:string; concept:string; xp_reward:number; position:number;
  category:string; duration_minutes:number; risk_note:string|null; level:string;
  learning_objectives:string[]; key_takeaways:string[]; content_json:Chapter[]; media_json:Media[]; quiz_json:Quiz[];
};
type Progress = { module_id:string; completed_at:string|null; score:number|null };

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://mxuevsspybxoovsutsbs.supabase.co",
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_Xs7hyyDA2XUkbwXGGfSE2w_tARkgSL7",
);

const levelLabel:Record<string,string>={beginner:"Débutant",intermediate:"Intermédiaire",advanced:"Avancé"};

export default function AcademyV2(){
  const[courses,setCourses]=useState<Course[]>([]);const[progress,setProgress]=useState<Progress[]>([]);const[selected,setSelected]=useState<Course|null>(null);const[loading,setLoading]=useState(true);
  useEffect(()=>{void(async()=>{const {data:auth}=await supabase.auth.getUser();const[c,p]=await Promise.all([
    supabase.from("learning_modules").select("id,slug,title,summary,concept,xp_reward,position,category,duration_minutes,risk_note,level,learning_objectives,key_takeaways,content_json,media_json,quiz_json").eq("is_active",true).order("position"),
    auth.user?supabase.from("learning_progress").select("module_id,completed_at,score").eq("user_id",auth.user.id):Promise.resolve({data:[]})
  ]);setCourses((c.data??[]) as Course[]);setProgress((p.data??[]) as Progress[]);setLoading(false)})()},[]);
  const completed=new Set(progress.filter(p=>p.completed_at).map(p=>p.module_id));const minutes=courses.reduce((n,c)=>n+c.duration_minutes,0);
  if(loading)return <section className="academy-v2"><div className="academy-loading">Chargement du cursus Konsens Academy…</div></section>;
  return <section className="academy-v2">
    <header className="academy-hero"><div><span>KONSENS ACADEMY · PARCOURS COMPLET</span><h1>Comprendre avant de risquer.</h1><p>Un cursus progressif de la gestion du budget jusqu’aux marchés, à la macro, aux probabilités et à la blockchain. Chaque module combine cours détaillé, exemples, schémas, ressources vidéo et quiz.</p></div><div className="academy-stats"><b>{courses.length}<small>modules</small></b><b>{Math.round(minutes/60)} h<small>de contenu</small></b><b>{completed.size}/{courses.length}<small>validés</small></b></div></header>
    <div className="academy-path">{courses.map((course,index)=>{const done=completed.has(course.id);return <button key={course.id} className={done?"course-card done":"course-card"} onClick={()=>setSelected(course)}><div className="course-index">{String(index+1).padStart(2,"0")}</div><div className="course-copy"><div className="course-meta"><span>{levelLabel[course.level]??course.level}</span><span>{course.duration_minutes} MIN</span><span>+{course.xp_reward} XP</span>{done&&<span className="done-pill">VALIDÉ</span>}</div><h2>{course.title}</h2><p>{course.summary}</p><div className="course-objectives">{course.learning_objectives.slice(0,3).map(x=><i key={x}>✓ {x}</i>)}</div></div><b className="course-arrow">→</b></button>})}</div>
    {selected&&<CourseReader course={selected} progress={progress.find(p=>p.module_id===selected.id)} close={()=>setSelected(null)} completed={()=>setProgress(old=>[...old.filter(p=>p.module_id!==selected.id),{module_id:selected.id,completed_at:new Date().toISOString(),score:100}])}/>} 
  </section>
}

function CourseReader({course,progress,close,completed}:{course:Course;progress?:Progress;close:()=>void;completed:()=>void}){
  const[chapter,setChapter]=useState(0);const[answers,setAnswers]=useState<Record<number,number>>({});const[result,setResult]=useState<number|null>(progress?.score??null);const current=course.content_json[chapter];
  const answered=Object.keys(answers).length===course.quiz_json.length;const score=useMemo(()=>course.quiz_json.length?Math.round(course.quiz_json.reduce((n,q,i)=>n+(answers[i]===q.answer?1:0),0)/course.quiz_json.length*100):100,[answers,course.quiz_json]);
  const validate=async()=>{if(!answered&&course.quiz_json.length)return;const {data:auth}=await supabase.auth.getUser();if(!auth.user)return;const finalScore=course.quiz_json.length?score:100;await supabase.from("learning_progress").upsert({user_id:auth.user.id,module_id:course.id,completed_at:new Date().toISOString(),score:finalScore},{onConflict:"user_id,module_id"});setResult(finalScore);if(finalScore>=70)completed()};
  return <div className="course-reader-backdrop"><article className="course-reader">
    <button className="reader-close" onClick={close} aria-label="Fermer">×</button>
    <aside className="reader-nav"><span>MODULE {String(course.position).padStart(2,"0")}</span><h2>{course.title}</h2><p>{course.duration_minutes} min · {levelLabel[course.level]??course.level}</p><nav>{course.content_json.map((c,i)=><button key={c.title} className={chapter===i?"active":""} onClick={()=>setChapter(i)}><b>{i+1}</b><span>{c.title}</span></button>)}</nav><div className="reader-takeaways"><strong>À retenir</strong>{course.key_takeaways.map(x=><p key={x}>• {x}</p>)}</div></aside>
    <main className="reader-main"><header><span>{course.category.toUpperCase()}</span><h1>{current?.title??course.title}</h1><p>{chapter===0?course.concept:"Approfondis le concept, puis confronte-le à l’exemple concret."}</p></header>
      {current&&<section className="chapter-body"><p>{current.body}</p>{current.example&&<div className="lesson-example"><span>EXEMPLE CONCRET</span><p>{current.example}</p></div>}{current.callout&&<blockquote>{current.callout}</blockquote>}</section>}
      <CourseMedia media={course.media_json} kind={course.media_json[0]?.kind}/>
      <div className="chapter-pager"><button disabled={chapter===0} onClick={()=>setChapter(x=>Math.max(0,x-1))}>← Chapitre précédent</button><span>{chapter+1}/{course.content_json.length}</span><button disabled={chapter===course.content_json.length-1} onClick={()=>setChapter(x=>Math.min(course.content_json.length-1,x+1))}>Chapitre suivant →</button></div>
      {chapter===course.content_json.length-1&&<section className="academy-quiz"><span>VALIDATION DU MODULE</span><h2>Teste ta compréhension.</h2>{course.quiz_json.map((q,i)=><div className="quiz-item" key={q.question}><h3>{i+1}. {q.question}</h3><div>{q.choices.map((choice,j)=><button key={choice} onClick={()=>setAnswers(a=>({...a,[i]:j}))} className={answers[i]===j?"chosen":""}>{choice}</button>)}</div>{answers[i]!==undefined&&<p className={answers[i]===q.answer?"quiz-ok":"quiz-no"}>{answers[i]===q.answer?"Bonne réponse. ":"À revoir. "}{q.explanation}</p>}</div>)}<button className="quiz-validate" disabled={!answered&&course.quiz_json.length>0} onClick={validate}>Valider le module</button>{result!==null&&<div className={result>=70?"quiz-result pass":"quiz-result"}><b>{result}%</b><span>{result>=70?"Module maîtrisé · XP validés":"Reprends les chapitres puis retente le quiz"}</span></div>}</section>}
      {course.risk_note&&<div className="academy-risk"><strong>Point de vigilance</strong><p>{course.risk_note}</p></div>}
    </main>
  </article></div>
}

function CourseMedia({media,kind}:{media:Media[];kind?:string}){return <section className="course-media"><div className="academy-diagram"><span>SCHÉMA INTERACTIF</span><Diagram kind={kind}/></div><div className="media-links"><span>VIDÉOS & SOURCES</span>{media.filter(m=>m.url).map(m=><a key={m.title} href={m.url} target="_blank" rel="noreferrer"><b>{m.type==="video"?"▶":"↗"}</b><div><strong>{m.title}</strong><small>{m.source??"Ressource pédagogique"}</small></div></a>)}</div></section>}

function Diagram({kind}:{kind?:string}){if(kind==="drawdown")return <svg viewBox="0 0 520 180"><path d="M10 45 L100 30 L190 50 L270 140 L350 110 L430 65 L510 35"/><line x1="10" y1="45" x2="510" y2="45"/><text x="275" y="158">-40% : la récupération exige ensuite +66,7%</text></svg>;if(kind==="diversification")return <div className="diagram-bubbles"><i/><i/><i/><i/><i/><i/><b>RISQUES<br/>DIFFÉRENTS</b></div>;if(kind==="blockchain")return <div className="diagram-chain"><i>TX</i><b>→</b><i>BLOC</i><b>→</b><i>CONFIRM.</i><b>→</b><i>EXPLORATEUR</i></div>;if(kind==="rates-bonds")return <div className="diagram-scales"><b>TAUX<br/><em>↑</em></b><i/><b>PRIX OBLIGATION<br/><em>↓</em></b></div>;if(kind==="calibration")return <svg viewBox="0 0 520 180"><line x1="40" y1="145" x2="470" y2="25"/><circle cx="120" cy="120" r="7"/><circle cx="220" cy="96" r="7"/><circle cx="315" cy="65" r="7"/><circle cx="410" cy="50" r="7"/><text x="40" y="170">Probabilité annoncée → fréquence observée</text></svg>;return <div className="diagram-order"><div><span>ACHETEURS</span><b>99,90</b><b>99,80</b></div><i>SPREAD</i><div><span>VENDEURS</span><b>100,10</b><b>100,20</b></div></div>}
