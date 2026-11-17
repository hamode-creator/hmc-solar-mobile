# رفع مشروع HMC Solar إلى GitHub وربطه مع Codemagic

1. افتح https://github.com/new وسجّل الدخول إلى نفس حساب GitHub المستخدم مع Codemagic.
2. Repository name: `hmc-solar-mobile`.
3. اختر Public بناءً على رغبتك، لكن تذكر أن كل الملفات المرفوعة تكون متاحة للآخرين.
4. اترك `Add a README file` **بدون تحديد** لأن المشروع يتضمن README جاهزاً. كذلك لا تضف قالب .gitignore تلقائياً.
5. اضغط `Create repository`.
6. فك ضغط ملف `HMC_Solar_Mobile_GitHub_Ready.zip` على الكمبيوتر. ارفع **محتويات** المجلد `hmc-solar-mobile` إلى جذر المستودع من `Add file → Upload files` في GitHub. لا ترفع ZIP كملف واحد. احتفظ بتسلسل مجلدات `flutter/lib/` و `flutter/assets/`.
7. تأكد أن رابط المستودع يحتوي على `codemagic.yaml` و`flutter/pubspec.yaml`.
8. ارجع إلى Codemagic واضغط تحديث المستودعات (Refresh)، ثم اختر `hmc-solar-mobile` وحدد `Flutter`.
9. شغّل Workflow اسمه `HMC Solar - iOS unsigned validation` أولاً. هذا اختبار بناء غير موقّع؛ ليس رفعاً إلى TestFlight.

**تحذير:** لا ترفع كلمات المرور أو ملفات مفاتيح Apple `.p8` أو Supabase service-role. خدمة App Attest على iOS لا تزال غير مفعلة في الخادم.
