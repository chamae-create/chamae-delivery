# Arquivo histórico — não usar no build

O JSON em `android/google-services.json` foi movido, sem modificar seus IDs internos, do diretório de build em 18/10/2026.

**INCOMPATÍVEL PARA PRODUÇÃO APÓS A MUDANÇA:** nenhum de seus clientes corresponde ao package oficial `br.com.loumak.chamae`. O arquivo é somente evidência da configuração anterior, não um template. Não copiar de volta, editar package_name nem reaproveitar appId/OAuth IDs.

Registrar um novo app Android com o package oficial no projeto Firebase `chamae-delivery`, configurar os certificados reais e baixar um novo JSON para `android/app/google-services.json`. Também registrar um novo app iOS com o mesmo Bundle ID oficial e obter seu plist. Regenerar `lib/firebase_options.dart` e os mapeamentos FlutterFire usando os apps oficiais.

Consultar [o relatório da migração](../../production_identifiers_migration_2026-10-18.md).
