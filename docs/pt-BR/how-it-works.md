# Como funciona

[English](../how-it-works.md) · **Português (Brasil)**

## Privacidade

Tudo acontece no seu Mac. **Nada é enviado para a Noha nem para ninguém.** Não há telemetria, analytics nem atualização automática. **O app não faz nenhuma requisição de rede própria** e nunca lê login, token nem senha.

O app atualiza a cada 5 minutos (a cada 15 quando você ficou 10 minutos ou mais sem usar o Mac), depois que o Mac acorda e quando você abre o painel com dados de mais de 3 minutos. Depois de um erro, ele espera mais para tentar de novo.

### Claude

- **Fonte.** Os limites que o próprio Claude Code entrega ao comando da barra de status, guardados pelo wrapper pequeno `aicontrolnotch-tap`. Veja [Barra de status do Claude Code](#barra-de-status-do-claude-code), abaixo.
- O app nunca lê o login do Claude Code, nunca mexe no Keychain e nunca chama a Anthropic.
- Os números atualizam sempre que o Claude Code roda. No intervalo, o notch mostra os últimos, e o ponto fica cinza depois de 30 minutos.
- Com várias sessões do Claude Code abertas, uma parada pode entregar números antigos. O notch guarda o maior uso visto em cada limite até ele renovar, então nunca baixa por engano.

### Codex

- **Fonte principal.** O app roda o `codex app-server` local, o que vem junto com o app do ChatGPT ou um CLI `codex` no seu Mac, e conversa com ele por stdio. O Codex lê os limites com o login dele. O AIControlNotch só recebe os números.
- **Reserva.** Os logs de sessão em `~/.codex/sessions` (e `~/.codex/archived_sessions`). Eles também guardam as suas conversas com o Codex: o app procura só a última entrada de limite de uso e não copia nem envia nada deles.
- O app nunca lê o `~/.codex/auth.json`.

### Modelos por script

Os scripts que você adiciona rodam localmente, com as suas permissões, sem shell e com um ambiente mínimo. Veja [Adicionar um modelo](add-a-model.md#como-os-scripts-rodam).

### O que ele guarda

Na sua conta de usuário:

- `~/Library/Application Support/AIControlNotch/`: os últimos números e o estado dos avisos (`state.json`), o seu `providers.json` e os seus scripts e, depois que o Claude é conectado, `tap.json` e `claude-statusline.json`. Os números salvos e o log só podem ser lidos por você.
- `~/Library/Logs/AIControlNotch/aicontrolnotch.log`: fatos curtos, como a fonte, o tipo de erro e o tempo. Nunca tokens nem corpos de resposta. Ele gira em 1 MB.

## Barra de status do Claude Code

É assim que o Claude se conecta. Cada vez que o Claude Code atualiza a barra de status, ele entrega ao comando dela um JSON que inclui os limites do seu plano. O wrapper `aicontrolnotch-tap` grava só os percentuais de 5 horas e da semana, com os horários de renovação, em `~/Library/Application Support/AIControlNotch/claude-statusline.json`, depois roda o seu comando original da barra de status com a mesma entrada e devolve a saída dele, então a sua barra de status continua funcionando. Precisa do Claude Code num terminal, com login num plano do Claude (Pro ou Max): com chave de API, o Claude Code não passa os limites do plano.

O `./scripts/install.sh` salva o seu comando atual da barra de status em `tap.json` e mostra o que mudar. **Ele nunca edita o `~/.claude/settings.json`: você faz isso, ou a sua IA faz com o seu OK.** Nesse arquivo, defina:

```json
"statusLine": {"type": "command", "command": "\"$HOME/Library/Application Support/AIControlNotch/bin/aicontrolnotch-tap\""}
```

Se você fizer manualmente, o `tap.json` guarda o seu comando original:

```json
{"command": "node ~/.claude/statusline.js"}
```

O `tap.json` roda pelo shell, então passa pelas mesmas checagens do `providers.json`: precisa ser seu e não pode ter permissão de escrita para outros usuários (`chmod 600` nele). Senão, a sua barra de status mostra `AIControlNotch: tap.json ignored:` e o motivo, em vez de rodar o comando.

Para desconectar o Claude, coloque o seu comando original de volta no `settings.json`.

## Menu

Clique com o botão direito no notch:

- **Atualizar agora**
- **Configurar modelos…**: cria o `providers.json` se preciso e abre
- **Recarregar modelos**: relê o `providers.json` agora
- **Abrir ao iniciar**
- uma linha por modelo: de onde vieram os números e há quanto tempo (e, se o `providers.json` foi recusado, o motivo)
- **Sair do AIControlNotch**

Não há ícone no Dock: o notch é o app.

## Linha de comando

A linha de comando fica dentro do pacote do app:

```bash
APP=/Applications/AIControlNotch.app/Contents/MacOS/AIControlNotch

$APP --launch-at-login on    # abrir ao iniciar (use off para desligar), e sair
$APP --demo                  # roda uma demonstração curta com números de exemplo no notch real, e sai
$APP --render-states <pasta> # grava um PNG de cada estado do notch em <pasta>, e sai
$APP --render-frames <pasta> --scene rest|open|alerts|models [--fps 30] [--scale 3]
                             # grava uma sequência de PNGs transparentes de uma cena animada, e sai
```

`--render-states` e `--render-frames` aceitam `--lang en` ou `--lang pt` para escolher o idioma. `--render-frames` grava `<pasta>/<cena>/frame-0000.png…` e um `scene.json` com o tamanho do quadro, a posição do notch e o momento de cada mudança de estado.

`--demo --snapshots <pasta>` também salva o que o painel mostra em cada passo.
