# frozen_string_literal: true

require "tty-prompt"
require "tty-table"
require "colorize"

module Biblioteca
  # Interface de terminal: menus com tty-prompt, tabelas com tty-table e cores com colorize.
  class CLI
    MENU = {
      "📖 Cadastrar livro" => :cadastrar,
      "📚 Listar livros" => :listar,
      "🔎 Ver detalhes de um livro" => :detalhes,
      "🔍 Buscar livros" => :buscar,
      "🧪 Busca avançada (combinar filtros)" => :busca_avancada,
      "✏️  Editar livro" => :editar,
      "🗑️  Remover livro" => :remover,
      "📊 Estatísticas" => :estatisticas,
      "🚪 Sair" => :sair
    }.freeze

    CRITERIOS = {
      "Título" => :titulo, "Autor" => :autor, "Ano de publicação" => :ano,
      "Categoria" => :categoria, "Status de leitura" => :status, "Avaliação" => :avaliacao
    }.freeze

    CAMPOS_EDICAO = {
      titulo: "Título", autor: "Autor", ano: "Ano", isbn: "ISBN", categoria: "Categoria",
      observacoes: "Observações", status: "Status", avaliacao: "Avaliação"
    }.freeze

    STATUS_VISUAL = {
      nao_lido: ["○", :light_black], lendo: ["◐", :yellow], lido: ["●", :green]
    }.freeze

    def initialize(acervo:, prompt: TTY::Prompt.new(interrupt: :exit), saida: $stdout, arquivo: nil)
      @acervo = acervo
      @prompt = prompt
      @saida = saida
      @arquivo = arquivo
    end

    def executar
      cabecalho
      loop do
        acao = @prompt.select("O que você quer fazer?", MENU, cycle: true, per_page: MENU.size)
        break if acao == :sair

        send(acao)
        @saida.puts
      end
      @saida.puts "Até a próxima leitura! 📚".cyan
    end

    private

    # ---------- Ações do menu ----------

    def cadastrar
      titulo("Novo livro")
      atributos = {
        titulo: @prompt.ask("Título:", required: true),
        autor: @prompt.ask("Autor:", required: true),
        ano: perguntar_ano,
        isbn: perguntar_isbn,
        categoria: perguntar_categoria,
        observacoes: @prompt.ask("Observações (opcional):")
      }
      atributos.merge!(perguntar_status)

      livro = @acervo.adicionar(atributos)
      sucesso("\"#{livro.titulo}\" cadastrado com o código #{livro.id}.")
    rescue ErroValidacao => e
      mostrar_erros(e)
    end

    def listar
      return aviso("A biblioteca está vazia. Comece cadastrando um livro.") if @acervo.vazio?

      titulo("Todos os livros")
      tabela(@acervo.ordenados)
    end

    def detalhes
      livro = escolher_livro or return
      mostrar_detalhes(livro)
    end

    def buscar
      return aviso("A biblioteca está vazia.") if @acervo.vazio?

      criterio = @prompt.select("Buscar por:", CRITERIOS, cycle: true)
      filtro, descricao = montar_filtro(criterio)
      mostrar_resultado(@acervo.filtrar(filtro), [descricao])
    end

    def busca_avancada
      return aviso("A biblioteca está vazia.") if @acervo.vazio?

      modo = @prompt.select("Busca avançada:", {
                              "Combinar critérios (o livro precisa atender a todos)" => :combinar,
                              "Usar um filtro pronto" => :prontos
                            })
      modo == :combinar ? combinar_criterios : filtro_pronto
    end

    def editar
      livro = escolher_livro or return
      alteracoes = {}

      loop do
        atual = livro.atributos.merge(alteracoes)
        campo = @prompt.select("Editando \"#{livro.titulo}\". Qual campo?",
                               opcoes_de_edicao(atual, alteracoes), cycle: true, per_page: 10)
        case campo
        when :cancelar then return aviso("Edição cancelada. Nada foi alterado.")
        when :salvar
          return aviso("Nenhum campo foi alterado.") if alteracoes.empty?

          begin
            novo = @acervo.atualizar(livro.id, alteracoes)
            sucesso("Alterações salvas.")
            return mostrar_detalhes(novo)
          rescue ErroValidacao => e
            mostrar_erros(e)
          end
        else
          alteracoes.merge!(perguntar_campo(campo, atual))
        end
      end
    end

    def remover
      livro = escolher_livro or return
      mostrar_detalhes(livro)

      if confirmar?("Remover \"#{livro.titulo}\" para sempre? Não dá para desfazer.")
        @acervo.remover(livro.id)
        sucesso("\"#{livro.titulo}\" foi removido.")
      else
        aviso("Remoção cancelada.")
      end
    end

    def estatisticas
      return aviso("Cadastre alguns livros para ver estatísticas.") if @acervo.vazio?

      relatorio = @prompt.select("Qual relatório?", {
                                   "Resumo geral" => :resumo, "Livros por autor" => :por_autor,
                                   "Livros por década" => :por_decada, "Top livros mais bem avaliados" => :top
                                 })
      send(:"relatorio_#{relatorio}", Estatisticas.new(@acervo))
    end

    # ---------- Relatórios ----------

    def relatorio_resumo(estatisticas)
      dados = estatisticas.resumo
      titulo("Resumo geral")
      @saida.puts "Total de livros: #{dados[:total].to_s.bold}"
      @saida.puts "Média de avaliação dos lidos: #{media(dados)}"

      subtitulo("Por status")
      linhas = dados[:por_status].map { |status, qtd| [status_visual(status), qtd, barra(qtd, dados[:total])] }
      tabela_simples(%w[Status Livros], linhas, alinhar: %i[left right left])

      subtitulo("Por categoria")
      linhas = dados[:por_categoria].map { |nome, qtd| [nome, qtd, barra(qtd, dados[:total])] }
      tabela_simples(%w[Categoria Livros], linhas, alinhar: %i[left right left])
    end

    def relatorio_por_autor(estatisticas)
      titulo("Livros por autor")
      autores = estatisticas.por_autor
      maior = autores.first&.last.to_i
      tabela_simples(%w[Autor Livros], autores.map { |nome, qtd| [nome, qtd, barra(qtd, maior)] },
                     alinhar: %i[left right left])
    end

    def relatorio_por_decada(estatisticas)
      titulo("Livros por década")
      dados = estatisticas.por_decada
      if dados[:decadas].empty?
        aviso("Nenhum livro tem ano de publicação.")
      else
        maior = dados[:decadas].map(&:last).max
        linhas = dados[:decadas].map { |decada, qtd| ["#{decada}s", qtd, barra(qtd, maior)] }
        tabela_simples(%w[Década Livros], linhas, alinhar: %i[left right left])
      end
      @saida.puts "Sem ano informado: #{dados[:sem_ano]}".light_black if dados[:sem_ano].positive?
    end

    def relatorio_top(estatisticas)
      titulo("Top livros mais bem avaliados")
      livros = estatisticas.top(10)
      return aviso("Nenhum livro lido foi avaliado ainda.") if livros.empty?

      linhas = livros.each_with_index.map do |livro, indice|
        ["#{indice + 1}º", truncar(livro.titulo, 40), truncar(livro.autor.nome, 24), estrelas(livro.avaliacao)]
      end
      tabela_simples(%w[# Título Autor Avaliação], linhas)
    end

    # ---------- Buscas ----------

    def montar_filtro(criterio)
      case criterio
      when :titulo
        termo = @prompt.ask("Título contém:", required: true)
        [Filtros.titulo(termo), "título contém \"#{termo}\""]
      when :autor
        termo = @prompt.ask("Autor contém:", required: true)
        [Filtros.autor(termo), "autor contém \"#{termo}\""]
      when :ano
        ano = perguntar_ano(obrigatorio: true)
        [Filtros.ano(ano), "ano #{ano}"]
      when :categoria
        categoria = escolher_categoria
        [Filtros.categoria(categoria), "categoria \"#{categoria}\""]
      when :status
        status = @prompt.select("Status:", Livro::STATUS.invert)
        [Filtros.status(status), "status \"#{Livro::STATUS[status]}\""]
      when :avaliacao
        valor = perguntar_faixa_de_avaliacao
        [Filtros.avaliacao(valor), "avaliação #{valor.is_a?(Range) ? "de #{valor.min} a #{valor.max}" : valor} ★"]
      end
    end

    def combinar_criterios
      criterios = @prompt.multi_select("Escolha os critérios (espaço marca, enter confirma):",
                                       CRITERIOS, min: 1, cycle: true)
      pares = criterios.map { |criterio| montar_filtro(criterio) }
      filtros = pares.map(&:first)
      mostrar_resultado(@acervo.filtrar(*filtros), pares.map(&:last))
    end

    def filtro_pronto
      prontos = Filtros.prontos
      nome = @prompt.select("Filtro:", prontos.keys, cycle: true)
      mostrar_resultado(@acervo.filtrar(prontos[nome]), [nome.downcase])
    end

    def mostrar_resultado(livros, descricoes)
      @saida.puts "Busca: #{descricoes.join(' e ')}".light_black
      if livros.empty?
        aviso("Nenhum livro encontrado.")
      else
        tabela(livros)
      end
    end

    # ---------- Perguntas ----------

    def perguntar_ano(obrigatorio: false, valor: nil)
      texto = obrigatorio ? "Ano:" : "Ano de publicação (opcional):"
      resposta = @prompt.ask(texto, value: valor.to_s, required: obrigatorio) do |q|
        q.validate(->(entrada) { Livro.ano_valido?(entrada) }, "Digite um ano entre 1 e #{Date.today.year}.")
      end
      resposta&.strip&.then { |ano| ano.empty? ? nil : ano.to_i }
    end

    def perguntar_isbn(valor: nil)
      @prompt.ask("ISBN (opcional):", value: valor.to_s) do |q|
        q.validate(->(entrada) { Livro.isbn_valido?(entrada) }, "O ISBN deve ter 10 ou 13 dígitos.")
      end
    end

    def perguntar_categoria(valor: nil)
      existentes = @acervo.categorias
      dica = existentes.empty? ? "" : " Já usadas: #{existentes.first(6).join(', ')}".light_black
      @saida.puts dica unless dica.empty?
      @prompt.ask("Categoria/gênero (opcional):", value: valor.to_s)
    end

    def perguntar_status(atual: nil)
      opcoes = Livro::STATUS.map { |chave, texto| { name: texto, value: chave } }
      padrao = Livro::STATUS.keys.index(atual || :nao_lido) + 1
      status = @prompt.select("Status de leitura:", opcoes, default: padrao)
      { status: status, avaliacao: status == :lido ? perguntar_avaliacao : nil }
    end

    def perguntar_avaliacao
      opcoes = Livro::AVALIACOES.to_a.reverse.map { |n| { name: "#{'★' * n}#{'☆' * (5 - n)}  (#{n})", value: n } }
      @prompt.select("Avaliação:", opcoes + [{ name: "Sem avaliação por enquanto", value: nil }])
    end

    def perguntar_faixa_de_avaliacao
      resposta = @prompt.ask("Avaliação (ex.: 5 ou 3-5):", required: true) do |q|
        q.validate(/\A\s*[1-5]\s*(-\s*[1-5]\s*)?\z/, "Use um número de 1 a 5 ou uma faixa como 3-5.")
      end
      minimo, maximo = resposta.split("-").map(&:to_i)
      maximo ? Range.new(*[minimo, maximo].sort) : minimo
    end

    def perguntar_campo(campo, atual)
      case campo
      when :titulo, :autor
        { campo => @prompt.ask("#{CAMPOS_EDICAO[campo]}:", value: atual[campo].to_s, required: true) }
      when :ano then { ano: perguntar_ano(valor: atual[:ano]) }
      when :isbn then { isbn: perguntar_isbn(valor: atual[:isbn]) }
      when :categoria then { categoria: perguntar_categoria(valor: atual[:categoria]) }
      when :observacoes
        { observacoes: @prompt.ask("Observações (vazio para apagar):", value: atual[:observacoes].to_s) }
      when :status then perguntar_status(atual: atual[:status])
      when :avaliacao
        return { avaliacao: perguntar_avaliacao } if atual[:status] == :lido

        aviso("Só livros lidos podem ser avaliados. Mude o status para \"Lido\" primeiro.")
        {}
      end
    end

    # Confirmação em português: aceita "s"/"sim" e "n"/"não"; Enter = não.
    def confirmar?(pergunta)
      @prompt.yes?(pergunta, default: false) do |q|
        q.suffix "s/N"
        q.positive "s"
        q.negative "n"
        q.convert ->(resposta) { Texto.normalizar(resposta).start_with?("s") }
      end
    end

    def escolher_livro
      if @acervo.vazio?
        aviso("A biblioteca está vazia.")
        return nil
      end

      opcoes = @acervo.ordenados.map do |livro|
        { name: "#{livro.id.to_s.rjust(3)}  #{livro.titulo} — #{livro.autor}", value: livro.id }
      end
      opcoes << { name: "← Voltar", value: :voltar }
      id = @prompt.select("Escolha o livro (digite para filtrar):", opcoes, filter: true, per_page: 10)
      id == :voltar ? nil : @acervo.encontrar(id)
    end

    def escolher_categoria
      categorias = @acervo.categorias
      return @prompt.ask("Categoria:", required: true) if categorias.empty?

      @prompt.select("Categoria:", categorias, cycle: true, per_page: 10)
    end

    def opcoes_de_edicao(atual, alteracoes)
      campos = CAMPOS_EDICAO.map do |campo, rotulo|
        marca = alteracoes.key?(campo) ? " *".yellow : ""
        { name: "#{rotulo.ljust(12)} #{valor_legivel(campo, atual[campo])}#{marca}", value: campo }
      end
      campos + [{ name: "💾 Salvar alterações", value: :salvar }, { name: "✖ Cancelar", value: :cancelar }]
    end

    # ---------- Exibição ----------

    def tabela(livros)
      linhas = livros.map do |livro|
        [livro.id, truncar(livro.titulo, 32), truncar(livro.autor.nome, 20), livro.ano || "—",
         truncar(livro.categoria || "—", 18), status_visual(livro.status), estrelas(livro.avaliacao)]
      end
      cabecalho = ["#", "Título", "Autor", "Ano", "Categoria", "Status", "Avaliação"].map(&:bold)
      tabela = TTY::Table.new(header: cabecalho, rows: linhas)
      @saida.puts tabela.render(:unicode, padding: [0, 1], resize: false, width: 200,
                                          alignments: %i[right left left right left left left])
      @saida.puts "#{livros.size} livro(s)".light_black
    end

    def tabela_simples(cabecalho, linhas, alinhar: nil)
      opcoes = { padding: [0, 1], width: 200, resize: false }
      opcoes[:alignments] = alinhar if alinhar
      tabela = TTY::Table.new(header: cabecalho.map(&:bold) + Array.new(linhas.first.size - cabecalho.size, ""),
                              rows: linhas)
      @saida.puts tabela.render(:unicode, **opcoes)
    end

    def mostrar_detalhes(livro)
      titulo(livro.titulo)
      {
        "Código" => livro.id, "Autor" => livro.autor, "Ano" => livro.ano, "ISBN" => livro.isbn,
        "Categoria" => livro.categoria, "Status" => status_visual(livro.status),
        "Avaliação" => estrelas(livro.avaliacao), "Observações" => livro.observacoes
      }.each do |rotulo, valor|
        @saida.puts "  #{rotulo.ljust(12).light_black} #{valor.nil? || valor.to_s.empty? ? '—' : valor}"
      end
    end

    def valor_legivel(campo, valor)
      case campo
      when :status then Livro::STATUS.fetch(valor, valor.to_s)
      when :avaliacao then valor ? "#{'★' * valor}#{'☆' * (5 - valor)}" : "—"
      else valor.nil? || valor.to_s.empty? ? "—" : truncar(valor.to_s, 40)
      end
    end

    def status_visual(status)
      simbolo, cor = STATUS_VISUAL.fetch(status, ["?", :default])
      "#{simbolo} #{Livro::STATUS.fetch(status, status.to_s)}".colorize(cor)
    end

    def estrelas(avaliacao)
      return "—".light_black if avaliacao.nil?

      ("★" * avaliacao).yellow + ("☆" * (5 - avaliacao)).light_black
    end

    def barra(quantidade, maximo, largura: 20)
      return "" if quantidade.zero? || maximo.zero?

      ("█" * [(quantidade * largura.to_f / maximo).round, 1].max).magenta
    end

    def media(dados)
      return "sem avaliações ainda".light_black if dados[:media_avaliacao].nil?

      "#{dados[:media_avaliacao].to_s.sub('.', ',').bold} ★ (#{dados[:avaliados]} livro(s) avaliado(s))"
    end

    def truncar(texto, limite)
      texto = texto.to_s
      texto.length > limite ? "#{texto[0, limite - 1]}…" : texto
    end

    def cabecalho
      @saida.puts "📚 Biblioteca Pessoal".bold.cyan
      detalhe = "#{@acervo.tamanho} livro(s)"
      detalhe += " · salvo em #{@arquivo}" if @arquivo
      @saida.puts detalhe.light_black
      @saida.puts
    end

    def titulo(texto)
      @saida.puts
      @saida.puts texto.bold.cyan
    end

    def subtitulo(texto)
      @saida.puts
      @saida.puts texto.bold
    end

    def sucesso(texto)
      @saida.puts "✅ #{texto}".green
    end

    def aviso(texto)
      @saida.puts "⚠️  #{texto}".yellow
    end

    def mostrar_erros(erro)
      @saida.puts "❌ Não foi possível salvar:".red
      erro.erros.each { |mensagem| @saida.puts "   • #{mensagem}".red }
    end
  end
end
