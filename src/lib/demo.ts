import type { AIResult, GenerateRequest } from "./types";

/**
 * Demo generator used when GEMINI_API_KEY is absent.
 * Produces realistic, schema-complete output so every UI feature
 * (steps, tooltips, quizzes, flashcards, XP) can be exercised offline.
 */
export function demoResult(req: GenerateRequest): AIResult {
  const ar = req.lang === "ar";
  const snippet = req.input.trim().slice(0, 60) || (ar ? "المدخل" : "your input");

  const recall = ar
    ? {
        quiz: [
          { question: "ما الهدف الرئيسي من الاسترجاع النشط؟", options: ["الحفظ السلبي", "تعزيز الذاكرة طويلة المدى", "تقليل وقت الدراسة فقط", "قراءة الملاحظات مرتين"], answerIndex: 1, explanation: "الاسترجاع النشط يجبر الدماغ على استدعاء المعلومة فيقوّي الروابط العصبية." },
          { question: "أي مما يلي يُعدّ بطاقة تعليمية جيدة؟", options: ["سؤال واحد بإجابة محددة", "فقرة طويلة", "صورة بلا نص", "قائمة بعشر نقاط"], answerIndex: 0, explanation: "البطاقة الجيدة تحمل فكرة واحدة فقط." },
          { question: "متى يُفضَّل مراجعة البطاقات؟", options: ["مرة واحدة فقط", "بفواصل زمنية متباعدة", "قبل الامتحان بدقائق", "لا حاجة للمراجعة"], answerIndex: 1, explanation: "التكرار المتباعد هو الأسلوب الأكثر فاعلية." },
        ],
        flashcards: [
          { front: "عرّف الاسترجاع النشط", back: "استدعاء المعلومة من الذاكرة دون النظر إلى المصدر." },
          { front: "ما التكرار المتباعد؟", back: "مراجعة المادة على فترات زمنية متزايدة." },
          { front: "لماذا تُستخدم الاختبارات القصيرة؟", back: "لكشف الفجوات المعرفية وتثبيت التعلم." },
        ],
      }
    : {
        quiz: [
          { question: "What is the main purpose of active recall?", options: ["Passive memorisation", "Strengthening long-term memory", "Reducing study time only", "Reading notes twice"], answerIndex: 1, explanation: "Retrieving information forces the brain to rebuild the memory trace, making it stronger." },
          { question: "Which is a well-designed flashcard?", options: ["One prompt, one precise answer", "A full paragraph", "An image with no text", "A ten-item list"], answerIndex: 0, explanation: "Atomic cards are easier to grade and remember." },
          { question: "When should flashcards be reviewed?", options: ["Only once", "At spaced intervals", "Minutes before the exam", "Never"], answerIndex: 1, explanation: "Spaced repetition is the most effective schedule." },
        ],
        flashcards: [
          { front: "Define active recall", back: "Retrieving information from memory without looking at the source." },
          { front: "What is spaced repetition?", back: "Reviewing material at increasing time intervals." },
          { front: "Why micro-quizzes?", back: "They expose knowledge gaps and consolidate learning." },
        ],
      };

  switch (req.module) {
    case "text":
      return {
        kind: "text",
        title: ar ? `تحضير النص: ${snippet}` : `Text Prep: ${snippet}`,
        coreIdeas: ar
          ? ["الصراع بين الواجب والرغبة الشخصية", "أثر البيئة في تكوين الشخصية", "قيمة الصبر والمثابرة"]
          : ["The tension between duty and personal desire", "How environment shapes character", "The value of patience and perseverance"],
        subThemes: ar
          ? [{ theme: "الهوية", explanation: "تتشكل هوية البطل عبر مواجهته للتحديات." }, { theme: "الزمن", explanation: "يُستخدم الزمن كرمز للتغير الحتمي." }]
          : [{ theme: "Identity", explanation: "The protagonist's identity forms through confronting adversity." }, { theme: "Time", explanation: "Time is used as a symbol of inevitable change." }],
        vocabulary: ar
          ? [{ word: "المثابرة", definition: "الاستمرار في العمل رغم الصعوبات", contextSentence: "أظهر البطل مثابرة نادرة." }, { word: "الحتمية", definition: "ما لا مفر منه", contextSentence: "كان التغيير حتمياً." }, { word: "الرمز", definition: "شيء يدل على معنى أعمق", contextSentence: "النهر رمز للزمن." }, { word: "السرد", definition: "طريقة حكاية الأحداث", contextSentence: "السرد بضمير المتكلم." }]
          : [{ word: "Perseverance", definition: "Continued effort despite difficulty (here: the hero's refusal to quit)", contextSentence: "Her perseverance carried her through the winter." }, { word: "Inevitable", definition: "Certain to happen; unavoidable", contextSentence: "Change was inevitable." }, { word: "Motif", definition: "A recurring symbolic element", contextSentence: "The river is a motif for time." }, { word: "Narrative voice", definition: "The perspective from which the story is told", contextSentence: "The first-person narrative voice builds intimacy." }],
        takeaways: ar ? ["الصبر مفتاح النجاح", "الاختيارات الصغيرة تصنع المصير"] : ["Patience is the key to growth", "Small choices shape destiny"],
        recall,
      };
    case "solver":
      return {
        kind: "solver",
        title: ar ? "حل المسألة خطوة بخطوة" : "Step-by-Step Solution",
        problemRestatement: ar
          ? `المطلوب: حل المسألة "${snippet}". (وضع تجريبي: أضف مفتاح GEMINI_API_KEY للحصول على حل حقيقي.)`
          : `Solve: "${snippet}". (Demo mode: add GEMINI_API_KEY for a real solution.)`,
        concepts: ar ? ["المعادلات الخطية", "خصائص المساواة"] : ["Linear equations", "Properties of equality"],
        steps: ar
          ? [
              { title: "الخطوة 1 – تحديد المعطيات", content: "نكتب المعادلة بشكلها القياسي ونحدد المجهول x.", why: "التنظيم يمنع الأخطاء ويوضح ما نبحث عنه." },
              { title: "الخطوة 2 – عزل الحد المجهول", content: "نطرح الثابت من الطرفين: 2x + 6 - 6 = 14 - 6 ⟹ 2x = 8.", why: "خاصية الطرح في المساواة تحافظ على توازن المعادلة." },
              { title: "الخطوة 3 – القسمة على المعامل", content: "نقسم الطرفين على 2: x = 4.", why: "القسمة تعكس عملية الضرب فتعزل x." },
              { title: "الخطوة 4 – التحقق", content: "2(4) + 6 = 14 ✓", why: "التحقق يكشف الأخطاء الحسابية قبل تسليم الواجب." },
            ]
          : [
              { title: "Step 1 – Identify knowns", content: "Write the equation in standard form and name the unknown x.", why: "Organising the givens prevents errors and clarifies the goal." },
              { title: "Step 2 – Isolate the variable term", content: "Subtract the constant from both sides: 2x + 6 − 6 = 14 − 6 ⟹ 2x = 8.", why: "The subtraction property of equality keeps both sides balanced." },
              { title: "Step 3 – Divide by the coefficient", content: "Divide both sides by 2: x = 4.", why: "Division undoes multiplication, leaving x alone." },
              { title: "Step 4 – Verify", content: "2(4) + 6 = 14 ✓", why: "Checking catches arithmetic slips before you submit." },
            ],
        finalAnswer: "x = 4",
        commonMistakes: ar ? ["نسيان تطبيق العملية على الطرفين", "خطأ في الإشارة عند الطرح"] : ["Applying an operation to only one side", "Sign errors when subtracting"],
        recall,
      };
    case "summary":
      return {
        kind: "summary",
        title: ar ? `ملخص الدرس: ${snippet}` : `Lesson Summary: ${snippet}`,
        bullets: ar
          ? ["الفكرة الرئيسية للدرس", "  - التعريف الأساسي", "  - الخصائص المهمة", "التطبيقات العملية", "  - مثال 1", "  - مثال 2", "الأخطاء الشائعة"]
          : ["Main concept of the lesson", "  - Core definition", "  - Key properties", "Practical applications", "  - Example 1", "  - Example 2", "Common pitfalls"],
        keyEquations: [
          { name: ar ? "قانون نيوتن الثاني" : "Newton's Second Law", formula: "F = m · a", meaning: ar ? "F القوة، m الكتلة، a التسارع" : "F force (N), m mass (kg), a acceleration (m/s²)" },
          { name: ar ? "الطاقة الحركية" : "Kinetic Energy", formula: "KE = ½ m v²", meaning: ar ? "v السرعة" : "v velocity (m/s)" },
        ],
        slideOutline: ar
          ? [{ slideTitle: "العنوان", points: ["اسم الدرس", "اسم الطالب"] }, { slideTitle: "المقدمة", points: ["لماذا هذا الموضوع مهم", "الأهداف"] }, { slideTitle: "المفاهيم الأساسية", points: ["تعريف", "قانون"] }, { slideTitle: "أمثلة", points: ["مثال محلول", "تطبيق"] }, { slideTitle: "الخاتمة", points: ["ملخص", "أسئلة"] }]
          : [{ slideTitle: "Title", points: ["Lesson name", "Presenter"] }, { slideTitle: "Introduction", points: ["Why it matters", "Objectives"] }, { slideTitle: "Core Concepts", points: ["Definition", "Law / formula"] }, { slideTitle: "Worked Examples", points: ["Example", "Application"] }, { slideTitle: "Conclusion", points: ["Recap", "Q&A"] }],
        recall,
      };
    case "dialect":
      return {
        kind: "dialect",
        title: ar ? `الشرح بالدارجة: ${snippet}` : `In Darija: ${snippet}`,
        dialectSummary: ar
          ? "باش تفهم الدرس مليح: خيال الشرح بالدارجة. (وضع تجريبي: أضف مفتاح GEMINI_API_KEY للحصول على شرح حقيقي.)"
          : "Ntaqol b darija: the lesson in plain words. (Demo mode: add GEMINI_API_KEY for a real explanation.)",
        everydayExamples: ar
          ? [{ example: "كيفاش نبيع و نشري", linkToConcept: "مثال على تبادل القيم" }, { example: "الماكلة فالسوق", linkToConcept: "مفهوم الطلب والعرض" }]
          : [{ example: "Chri w be3 f souq", linkToConcept: "Exchange of value — supply and demand" }, { example: "Traj f 7out", linkToConcept: "Scarcity raises price" }],
        examTermGlossary: [
          { dialectTerm: ar ? "الحساب" : "l-hsab", formalTerm: ar ? "الحساب الرياضي" : "Arithmetic", meaning: ar ? "العمليات على الأعداد" : "Operations on numbers" },
          { dialectTerm: ar ? "الميزان" : "l-mizan", formalTerm: ar ? "المعادلة" : "Equation", meaning: ar ? "تساوي طرفين" : "Two equal sides" },
        ],
        quickSteps: ar ? ["قرا السؤال مرتين", "كتب المعطيات", "طبق القانون"] : ["Read the question twice", "Write down the givens", "Apply the formula"],
        recall,
      };
    case "grammar":
      return {
        kind: "grammar",
        title: ar ? "التحليل اللغوي" : "Grammar Analysis",
        correctedText: req.input.trim() || (ar ? "ذهب الطالبُ إلى المدرسةِ مبكراً." : "The student went to school early."),
        issues: ar
          ? [{ original: "ذهب الطالب الى", fix: "ذهب الطالبُ إلى", rule: "همزة القطع في «إلى» واجبة." }]
          : [{ original: "goed", fix: "went", rule: "'Go' is an irregular verb; its past tense is 'went'." }],
        sentenceAnalysis: ar
          ? [{ part: "ذهب", role: "فعل ماضٍ", note: "مبني على الفتح" }, { part: "الطالبُ", role: "فاعل", note: "مرفوع وعلامة رفعه الضمة" }, { part: "إلى المدرسةِ", role: "جار ومجرور", note: "متعلق بالفعل" }, { part: "مبكراً", role: "حال", note: "منصوب" }]
          : [{ part: "The student", role: "Subject (noun phrase)", note: "Definite article + noun" }, { part: "went", role: "Main verb", note: "Past simple, irregular" }, { part: "to school", role: "Prepositional phrase", note: "Adverbial of place" }, { part: "early", role: "Adverb", note: "Adverbial of time" }],
        translation: ar
          ? { targetLanguage: "English", text: "The student went to school early.", notes: "«مبكراً» ترجمت إلى early كظرف زمان." }
          : { targetLanguage: "Arabic", text: "ذهب الطالبُ إلى المدرسةِ مبكراً.", notes: "Arabic places the verb first (VSO order)." },
        recall,
      };
  }
}
