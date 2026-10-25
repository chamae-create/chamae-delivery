# Correção final do Splash — NUU M2 — 21/10/2026

## Escopo e causa do branco

O branco foi isolado no preview de abertura legado do Android 7/API 24, antes da Activity e antes do primeiro frame Flutter. Confirmado por gravações A/B: temas dourados, fundo programático da janela e cor literal no tema, isoladamente, não eliminaram esse preview; `windowDisablePreview=true` eliminou o branco. As tentativas programáticas e a alteração do tema global da aplicação foram retiradas.

Configuração final: preview legado desabilitado, fundos LaunchTheme/NormalTheme dourados (#EAB124), primeiro frame do aplicativo dourado. Enquanto o processo inicia, o launcher permanece visível; não existe timer nativo, tela intermediária branca ou espera adicionada para esconder o problema. Em values-v31/values-night-v31, o preview do sistema permanece habilitado e o Splash obrigatório do Android 12+ mantém fundo dourado e ícone existente. Android 12+ e iOS não foram validados fisicamente nesta etapa.

## Arte, enquadramento e animação

A imagem oficial permanece byte a byte íntegra. Fonte 740×1600; SHA-256: 9dfae65937d04da00d2165c0e9a17148389811546c2ebc9e1df798ad9e464eda.

`BoxFit.cover`, alinhamento inferior central e escala uniforme preenchem o viewport. No NUU M2, o recorte está na área dourada superior; Chamaê, BEBIDAS E CONVENIÊNCIA e Loumak permanecem visíveis. As antigas faixas e seus gradientes laterais foram removidos. Não há esticamento independente de largura/altura. O ajuste foi verificado em retrato; proporções extremas/landscape exigem uma arte oficial própria para preservar a mesma composição integral.

- Animação finita: 2.500 ms. Inicialização real ocorre em paralelo.
- Fade de entrada: aproximadamente 450 ms, iniciando em 1% de opacidade para antecipar a primeira pintura do JPEG.
- Zoom uniforme: 100% → 100,8%, ancorado embaixo, sem cortar elementos principais no NUU.
- Luz dourada atravessa a região da marca; intensidade máxima de 32% modulada suavemente.
- Oito pequenas luzes determinísticas se deslocam discretamente e desaparecem; sem blur, partículas externas, animação infinita ou SDK.
- Filtro bilinear leve e imagem decodificada na largura física necessária; RepaintBoundary preserva a arte estática entre os frames dos efeitos.
- Transição ao destino real: fade de 300 ms. Experiência programada total de aproximadamente 2,8 s quando a sessão já está pronta. Se a inicialização real demorar mais, a segurança da sessão prevalece; ela não é antecipada nem contornada.
- Movimento reduzido apresenta arte estática imediatamente e dispensa espera/animação de saída.
- Falha, retry, descarte do widget e espera pela sessão continuam protegidos pelos testes.

## Testes proporcionais

- `flutter analyze --no-pub`: sem issues.
- `flutter test --no-pub test/splash_official_test.dart -r expanded`: 11 aprovados.
- `flutter test --no-pub test/client_readiness_test.dart --plain-name splash -r expanded`: 2 aprovados.
- `flutter test --no-pub test/customer_flow_test.dart -r expanded`: 14 aprovados. Este arquivo exercita o Splash como entrada dos fluxos de sessão; foi executado por relação direta com a navegação alterada, com fakes, sem backend/emuladores.
- Não executadas suíte Flutter completa, Functions, Web ou Firestore Rules.

## Arquivos desta correção

- lib/screens/splash_screen.dart
- android/app/src/main/res/values/styles.xml
- android/app/src/main/res/values-night/styles.xml
- android/app/src/main/res/values-v31/styles.xml
- android/app/src/main/res/values-night-v31/styles.xml
- test/splash_official_test.dart
- test/client_readiness_test.dart (somente o teste do Splash; remanescentes da Home preservados)
- tool/visual_splash/main.dart (momento de coleta de métricas)
- tool/visual_splash/capture.ps1 (nova pasta de evidência e momento de captura)
- docs/splash_final_correction_2026-10-21/ (evidências desta correção)

Home, outras telas, main.dart, componentes compartilhados, inicializador Firebase, autenticação, pagamentos e regras permaneceram intactos nesta correção. Assets, pubspec, drawables dourados e storyboard iOS já alterados na fase anterior foram preservados. Manifest e MainActivity retornaram exatamente aos bytes existentes antes da investigação.

## Evidências e limites

NUU M2 físico, serial LDM2171600957, Android 7/API 24, 720×1280 físicos, 360×640 lógicos, densidade 320, fonte 1,0, display medido em 66,13 Hz.

PNG em resolução física; vídeo reduzido automaticamente pelo encoder do Android 7 para 368×640. O vídeo serve para conferir continuidade e efeitos, sem equivaler a captura de alta velocidade ou medição precisa de FPS. Os arquivos cold_*_start.txt medem a apresentação da Activity, não a duração total do Splash.

Capturas official_splash.png, reduced_motion.png, error_retry.png, cold_01_metrics.png, cold_02_metrics.png, reopen_no_replay.png e cold_sequence.mp4 usam o Splash de produção num harness profile com inicialização LOCAL de 1100 ms e destino neutro. O harness não acessa Firebase nem dados reais. A validação do aplicativo real é registrada separadamente; vídeos privados de eventual destino real ficam em .dart_tool, fora do Git.

Resultados físicos finais e integridade: ver validation.json, gerado ao concluir a checagem.

Sem stage, commit, push, deploy, publicação de regras/Functions/Hosting ou release de loja.
## Resultado físico final

Aplicativo REAL em profile, sem fixture de sessão: duas aberturas frias com apresentação da Activity em 1.482 ms e 994 ms; retomada em 37 ms. Splash exibido proporcionalmente, sem branco/faixas, com marca, texto e Loumak completos, seguido do onboarding existente. Não houve interação com login, consentimentos ou dados operacionais. O screenshot `actual_app_splash.png` foi extraído diretamente desse APK, durante os efeitos. O APK real profile permanece instalado para revisão local.

O build debug apresentou inicialização lenta: am start atingiu timeout de 10.063 ms e houve uma janela preta antes do Flutter; posteriormente chegou ao onboarding existente. Portanto, não se afirma que a partida JIT/debug esteja homologada. As conclusões de fluidez e abertura normal são do build AOT/profile, apropriado para medição, não de release de loja.

Métricas do componente em profile, sem gravação simultânea: primeira abertura após instalação com 164 frames, nenhum build acima do orçamento de 15,12 ms e cinco frames raster acima dele (pico 126,264 ms). Segunda abertura: 175 frames, nenhum build acima do orçamento e três raster acima (pico 30,875 ms). Não se afirma ausência absoluta de jank. O pico de primeira pintura permanece como ressalva para aprovação visual no aparelho; não houve ANR ou falha funcional observada.

`git diff --check` aprovado. Verificação por SHA-256 confirmou preservação da Home, demais telas/remanescentes, manifest, MainActivity e local.properties. As alterações anteriores legítimas do teste client_readiness foram verificadas separadamente do bloco do Splash e continuam preservadas.