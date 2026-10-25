# Splash oficial — validação de 21/10/2026

## Arte e escopo

Fonte fornecida pelo proprietário: `C:/Users/DELL/OneDrive/Imagens/logo oficial chamae.jpeg`, 740×1600, 93.639 bytes.
Cópia de produção: `assets/images/splash/chamae_official_gold_2026_10_21.jpeg`.
SHA-256 original/cópia: `9dfae65937d04da00d2165c0e9a17148389811546c2ebc9e1df798ad9e464eda`.
A arte é oficial e foi copiada byte a byte, sem redesenho, geração ou edição. Marca, texto, luzes e Loumak continuam na própria imagem.

Apenas Splash, registro do asset e launch nativo foram implementados. As sete telas, Firebase, autenticação, pagamentos, estoque, catálogo e regras não foram alterados nesta fase. Remanescentes anteriores protegidos por snapshot de hashes e cópias de preservação.

## Animação e encaminhamento

- Entrada por opacidade em até195ms, sobre fundo dourado.
- Zoom de99,4% a100%, sem ultrapassar/cortar a composição, em650ms.
- Uma passagem de luz com alpha máximo9% na região da marca, entre130 e598ms. Sem partículas, blur, efeito repetitivo ou biblioteca nova.
- Ao completar650ms, a tela fica estática se a inicialização ainda não terminou.
- A inicialização real determina a saída: não há espera estética mínima. Se terminar antes, o splash avança sem esperar a animação.
- Transição para o destino existente: fade180ms. Com reduzir animações: imagem estática em100% e transição sem animação.
- Falha/retry preservados, com mensagem acessível sobre a arte; erro não congela o app.
- Voltar do background não cria outra tela nem reinicia autenticação por lógica nova.

## Ajuste inevitável de proporção

A arte740×1600 é mais estreita que o NUU M2 720×1280. Usa-se contain, preservando a composição completa, sem esticar ou cortar Loumak. As margens são preenchidas com gradiente de cores amostradas das bordas da própria arte. Em outras proporções/orientações haverá margens diferentes. A área útil depende das barras do sistema; sua presença deve ser considerada na comparação.

## Launch nativo e plataformas

Android<=11/API24: launch estático dourado, incluindo recurso drawable-v21 e temas claro/escuro. Android12+: recurso específico mantém a splash do sistema e o ícone de launcher existente sobre dourado; a arte completa e animação entram no Flutter. Não foi adicionado AndroidX/plugin/SDK ou alterado o ícone do aplicativo.
iOS: storyboard continua estático, agora dourado. As imagens LaunchImage existentes foram verificadas como totalmente transparentes e preservadas. A arte e animação pertencem ao Flutter, sem código de animação no launch screen.

Fontes consultadas: [Android SplashScreen](https://developer.android.com/develop/ui/views/launch/splash-screen), [migração Android12](https://developer.android.com/develop/ui/views/launch/splash-screen/migrate), [Apple Launching](https://developer.apple.com/design/human-interface-guidelines/launching), [Apple launch screen](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen). Não é certificação de aprovação das lojas. iOS físico e Android12+ físico não estão disponíveis nesta homologação API24.

## Harness e limites de evidência

`tool/visual_splash/main.dart` usa o SplashScreen de produção, inicialização LOCAL e destino neutro, sem Firebase ou dados reais. Executa em debug/profile e recusa release. F1=repetir abertura; F2=arte estática após animação; F3=erro; F4=inicialização imediata; F5=movimento reduzido.

O initializer LOCAL de1100ms serve somente para registrar a sequência; NÃO foi inserido em produção. As métricas registram build/raster por FrameTiming do Flutter, incluindo custo de primeiro frame/decode. Build profile do harness evita overhead debug, mas não substitui benchmark de release do aplicativo completo.

## Resultados

A preencher com as evidências físicas e os resultados finais antes de encerrar.
