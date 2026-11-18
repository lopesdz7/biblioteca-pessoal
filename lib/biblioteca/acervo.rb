# frozen_string_literal: true

module Biblioteca
  # A coleção de livros. Cuida das regras de cadastro, edição, remoção e busca,
  # e avisa quem estiver ouvindo (callbacks) sempre que algo muda.
  class Acervo
    include Enumerable

    def initialize(livros = [])
      @livros = livros.dup
      @ouvintes = []
    end

    # Registra um callback chamado com (evento, livro) após cada alteração.
    # Eventos: :adicionado, :atualizado, :removido.
    def ao_alterar(&bloco)
      @ouvintes << bloco
      self
    end

    def each(&)
      @livros.each(&)
    end

    def tamanho
      @livros.size
    end

    def vazio?
      @livros.empty?
    end

    def ordenados
      sort_by { |livro| [Texto.normalizar(livro.titulo), livro.id] }
    end

    def encontrar(id)
      @livros.find { |livro| livro.id == id.to_i }
    end

    def encontrar!(id)
      encontrar(id) || raise(LivroNaoEncontrado, id)
    end

    def categorias
      @livros.filter_map(&:categoria).uniq { |categoria| Texto.normalizar(categoria) }.sort_by { |c| Texto.normalizar(c) }
    end

    def adicionar(atributos)
      livro = Livro.new(**atributos.slice(*Livro::CAMPOS), id: proximo_id).validar!
      @livros << livro
      notificar(:adicionado, livro)
    end

    def atualizar(id, alteracoes)
      atual = encontrar!(id)
      novo = Livro.new(**atual.atributos.merge(alteracoes.slice(*Livro::CAMPOS)),
                       id: atual.id, criado_em: atual.criado_em, atualizado_em: Time.now.iso8601).validar!
      @livros[@livros.index(atual)] = novo
      notificar(:atualizado, novo)
    end

    def remover(id)
      livro = encontrar!(id)
      @livros.delete(livro)
      notificar(:removido, livro)
    end

    # Recebe qualquer quantidade de filtros (lambdas/procs) e, opcionalmente,
    # um bloco como filtro extra. O livro precisa passar em todos.
    #
    #   acervo.filtrar(Filtros.autor("asimov")) { |livro| livro.ano < 1960 }
    def filtrar(*filtros, &bloco)
      filtros << bloco if bloco
      ordenados.select(&Filtros.todos(*filtros))
    end

    private

    def proximo_id
      (@livros.map(&:id).max || 0) + 1
    end

    def notificar(evento, livro)
      @ouvintes.each { |ouvinte| ouvinte.call(evento, livro) }
      livro
    end
  end
end
