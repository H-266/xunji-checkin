/// 项目主页；关于页只做“复制链接”，不申请网络权限、不内置 WebView。
const String projectUrl = 'https://github.com/xunji-checkin/xunji-checkin';

/// 支持项目板块在关于页的锚点标识。
const String supportSectionKey = 'support-section';

/// 联系方式：全版本展示，不申请任何权限，点击通过系统 mailto 唤起邮件应用。
const String contactEmailQq = '3698910396@qq.com';
const String contactEmailOutlook = 'dazuo03@outlook.com';

/// 关于页所需文案；联系方式全语言保留，赞赏文案仅中文开源版使用。
class AboutCopy {
  final String appName;
  final String tagline;
  final String developerHeading;
  final String developerBody;
  final String projectHeading;
  final String linkCopied;
  final String contactHeading;
  final String qqLabel;
  final String outlookLabel;
  final String contactHint;
  final String mailUnavailable;
  final String supportHeading;
  final String supportBody;
  final String wechatLabel;
  final String alipayLabel;
  final String supportHint;

  const AboutCopy({
    required this.appName,
    required this.tagline,
    required this.developerHeading,
    required this.developerBody,
    required this.projectHeading,
    required this.linkCopied,
    required this.contactHeading,
    required this.qqLabel,
    required this.outlookLabel,
    required this.contactHint,
    required this.mailUnavailable,
    required this.supportHeading,
    required this.supportBody,
    required this.wechatLabel,
    required this.alipayLabel,
    required this.supportHint,
  });

  static AboutCopy of(String lang) {
    if (lang == 'zh') {
      return const AboutCopy(
        appName: '循记打卡',
        tagline: 'v1.0.1 · 纯离线 · 无广告无内购',
        developerHeading: '关于开发者 H.266',
        developerBody: 'H.266 是一名来自中国的 14 岁独立开发者。\n本项目完全免费、无广告、纯离线，所有功能永久开放。',
        projectHeading: '项目主页',
        linkCopied: '链接已复制，可粘贴到浏览器打开',
        contactHeading: '联系与反馈',
        qqLabel: 'QQ 邮箱',
        outlookLabel: '微软邮箱',
        contactHint: '如有问题或建议，欢迎通过邮件联系我。',
        mailUnavailable: '未找到可用的邮件应用',
        supportHeading: '支持项目',
        supportBody: '如果循记打卡帮到了你，欢迎用微信或支付宝赞赏支持我持续更新。赞赏完全自愿，不影响任何功能。',
        wechatLabel: '微信赞赏',
        alipayLabel: '支付宝赞赏',
        supportHint: '点击收款码可放大查看；赞赏纯属自愿。',
      );
    }
    if (lang == 'zh_Hant') {
      return const AboutCopy(
        appName: '循記打卡',
        tagline: 'v1.0.1 · 純離線 · 無廣告、無內購',
        developerHeading: '關於開發者 H.266',
        developerBody: 'H.266 是來自中國的 14 歲獨立開發者。\\n本專案完全免費、無廣告、純離線，所有功能永久開放。',
        projectHeading: '專案首頁',
        linkCopied: '連結已複製，可貼到瀏覽器開啟',
        contactHeading: '聯絡與回饋',
        qqLabel: 'QQ 信箱',
        outlookLabel: 'Microsoft 信箱',
        contactHint: '如有問題或建議，歡迎透過電子郵件聯絡我。',
        mailUnavailable: '未找到可用的郵件應用程式',
        supportHeading: '支持專案',
        supportBody: '如果循記打卡對你有幫助，歡迎用微信或支付寶贊助支持我持續更新。贊助完全自願，不影響任何功能。',
        wechatLabel: '微信贊助',
        alipayLabel: '支付寶贊助',
        supportHint: '點擊收款碼可放大查看；贊助純屬自願。',
      );
    }
    if (lang == 'ja') {
      return const AboutCopy(
        appName: '循記チェックイン',
        tagline: 'v1.0.1 · 完全ローカル · 広告・課金なし',
        developerHeading: '開発者 H.266 について',
        developerBody: 'H.266 は中国出身の 14 歳のフリー開発者です。\n本プロジェクトは完全無料、広告なし、完全オフラインで、全機能が永久に利用可能です。',
        projectHeading: 'GitHub · スターで応援',
        linkCopied: 'リンクをコピーしました。ブラウザに貼り付けて開けます',
        contactHeading: 'お問い合わせ・フィードバック',
        qqLabel: 'QQ メール',
        outlookLabel: 'Outlook',
        contactHint: 'ご質問やご意見がございましたら、メールにてお問い合わせください。',
        mailUnavailable: 'メールアプリが見つかりません',
        supportHeading: '',
        supportBody: '',
        wechatLabel: '',
        alipayLabel: '',
        supportHint: '',
      );
    }
    if (lang == 'fr') {
      return const AboutCopy(
        appName: 'Xunji Check-in',
        tagline: 'v1.0.1 · 100 % local · sans pub ni achat',
        developerHeading: 'À propos du développeur H.266',
        developerBody: "H.266 est un développeur indépendant de 14 ans originaire de Chine.\nCe projet est entièrement gratuit, sans publicité et 100 % hors ligne, avec toutes les fonctionnalités accessibles à vie.",
        projectHeading: 'GitHub · Ajouter une étoile',
        linkCopied: 'Lien copié. Collez-le dans votre navigateur',
        contactHeading: 'Contact et retours',
        qqLabel: 'QQ Mail',
        outlookLabel: 'Outlook',
        contactHint: "N'hésitez pas à me contacter par mail pour toute question ou suggestion.",
        mailUnavailable: 'Aucune application de messagerie trouvée',
        supportHeading: '',
        supportBody: '',
        wechatLabel: '',
        alipayLabel: '',
        supportHint: '',
      );
    }
    if (lang == 'es') {
      return const AboutCopy(
        appName: 'Xunji Check-in',
        tagline: 'v1.0.1 · 100 % local · sin anuncios ni compras',
        developerHeading: 'Sobre el desarrollador H.266',
        developerBody: 'H.266 es un desarrollador independiente de 14 años de China.\nEste proyecto es completamente gratuito, sin anuncios y totalmente offline, con todas las funciones disponibles permanentemente.',
        projectHeading: 'GitHub · Dar una estrella',
        linkCopied: 'Enlace copiado. Pégalo en el navegador',
        contactHeading: 'Contacto y comentarios',
        qqLabel: 'QQ Mail',
        outlookLabel: 'Outlook',
        contactHint: 'No dudes en contactarme por correo si tienes alguna pregunta o sugerencia.',
        mailUnavailable: 'No se encontró ninguna app de correo',
        supportHeading: '',
        supportBody: '',
        wechatLabel: '',
        alipayLabel: '',
        supportHint: '',
      );
    }
    return const AboutCopy(
      appName: 'Xunji Check-in',
      tagline: 'v1.0.1 · Fully offline · no ads, no purchases',
      developerHeading: 'About Developer H.266',
      developerBody: 'H.266 is a 14-year-old independent developer from China.\nThis project is completely free, ad-free and offline-only, with all features permanently available.',
      projectHeading: 'GitHub · Star the project',
      linkCopied: 'Link copied. Paste it into your browser',
      contactHeading: 'Contact & Feedback',
      qqLabel: 'QQ Mail',
      outlookLabel: 'Outlook',
      contactHint: 'Feel free to reach out via email if you have any questions or suggestions.',
      mailUnavailable: 'No email app found',
      supportHeading: '',
      supportBody: '',
      wechatLabel: '',
      alipayLabel: '',
      supportHint: '',
    );
  }
}
