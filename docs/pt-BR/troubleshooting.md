# Solução de problemas

[English](../troubleshooting.md) · **Português (Brasil)**

**O Claude não mostra dados.**
O Claude se conecta pela [barra de status do Claude Code](how-it-works.md#barra-de-status-do-claude-code). Confira se o `statusLine` no `~/.claude/settings.json` roda o `aicontrolnotch-tap` (`plutil -extract statusLine.command raw -o - ~/.claude/settings.json` mostra só essa linha), use o Claude Code uma vez num terminal e escolha **Atualizar agora**. O Claude Code só passa os limites do plano quando o login é num plano do Claude (Pro ou Max), não com chave de API.

**A minha barra de status mostra "AIControlNotch: tap.json ignored".**
O `tap.json` guarda o seu comando original da barra de status, então precisa ser seu e privado: `chmod 600 ~/Library/Application\ Support/AIControlNotch/tap.json`.

**O Codex não mostra dados.**
Abra o Codex (o app do ChatGPT ou o CLI `codex`) uma vez e entre na conta. O app procura o `codex` no seu `PATH`, depois em `/Applications/ChatGPT.app`, `/Applications/Codex.app`, `~/.local/bin` e `/opt/homebrew/bin`. Se não achar nenhum, usa os logs de sessão, que só atualizam enquanto o Codex roda.

**Eu não uso o Claude ou o Codex.**
Clique com o botão direito no notch, escolha **Configurar modelos…** e coloque o id dele (`claude` ou `codex`) em `disabled`. Pelo menos um modelo precisa ficar habilitado.

**Os números parecem velhos.**
O menu mostra a fonte e a idade de cada modelo. Um ponto cinza significa dado com mais de 30 minutos. Os números do Claude, e os do Codex quando vêm dos logs de sessão, só atualizam enquanto o Claude Code ou o Codex está rodando.

**Um modelo por script mostra um erro.**
A mensagem no painel diz qual script e o motivo. Rode o script no terminal e passe a saída por `python3 -m json.tool` para ver o que ele imprime. As regras estão em [Adicionar um modelo](add-a-model.md#como-os-scripts-rodam).

**"Outros usuários podem alterar os arquivos dele".**
O script, um arquivo citado nos argumentos ou uma pasta onde eles estão pode ser alterado por outros usuários deste Mac. Rode `chmod go-w` neles.

**Não aparece nada no topo da tela.**
Só uma cópia roda por vez e não há ícone no Dock. Procure `AIControlNotch` no Monitor de Atividade ou abra de novo pela pasta `/Applications`.

**A compilação falha.**
Confira se `swift --version` mostra Swift 6 ou mais novo. Se não mostrar, atualize o Xcode ou as Command Line Tools em **Ajustes do Sistema > Geral > Atualização de Software**, ou rode `xcode-select --install`.

**Onde fica o log?**
`~/Library/Logs/AIControlNotch/aicontrolnotch.log`. Ele não tem tokens, mas leia antes de colar em algum lugar:

```bash
tail -n 50 ~/Library/Logs/AIControlNotch/aicontrolnotch.log
```

Ainda com problema? Abra um [relato de bug](https://github.com/noha-agencia/AIControlNotch/issues/new/choose).
