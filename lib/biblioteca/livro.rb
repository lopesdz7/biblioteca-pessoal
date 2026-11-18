# frozen_string_literal: true

require "date"

module Biblioteca
  # Um livro da biblioteca. Herda id e datas de Registro.
  # É imutável: editar cria um novo Livro com os campos alterados (veja Acervo#atualizar).
  class Livro < Registro
    STATUS = { nao_lido: "Não lido", lendo: "Lendo", lido: "Lido" }.freeze
    CAMPOS = %i[titulo autor ano isbn categoria observacoes status avaliacao].freeze
    AVALIACOES = (1..5).freeze

    attr_reader :titulo, :autor, :ano, :isbn, :categoria, :observacoes, :status, :avaliacao

    def self.from_h(hash)
      dados = hash.transform_keys(&:to_sym)
      new(**dados.slice(*CAMPOS, :id, :criado_em, :atualizado_em))
    end

    def self.ano_valido?(valor)
      valor.nil? || valor.to_s.strip.empty? ||
        (valor.to_s.strip.match?(/\A\d{1,4}\z/) && valor.to_i.between?(1, Date.today.year))
    end

    # Aceita ISBN-10 (pode terminar com X) ou ISBN-13, com ou sem hífens e espaços.
    def self.isbn_valido?(valor)
      return true if valor.nil? || valor.to_s.strip.empty?

      digitos = valor.to_s.delete("- ").upcase
      digitos.match?(/\A\d{9}[\dX]\z/) || digitos.match?(/\A\d{13}\z/)
    end

    # Aceita o símbolo (:nao_lido), o texto ("Não lido") ou a chave em texto ("nao_lido").
    def self.status_de(valor)
      return :nao_lido if valor.nil? || valor.to_s.strip.empty?
      return valor.to_sym if STATUS.key?(valor.to_s.to_sym)

      STATUS.find { |_chave, texto| Texto.normalizar(texto) == Texto.normalizar(valor) }&.first || valor.to_s
    end

    def initialize(titulo:, autor:, ano: nil, isbn: nil, categoria: nil, observacoes: nil,
                   status: :nao_lido, avaliacao: nil, **registro)
      super(**registro)
      @titulo = Texto.limpar(titulo)
      @autor = autor.is_a?(Autor) ? autor : Autor.new(autor)
      @ano = inteiro(ano)
      @isbn = Texto.limpar(isbn)
      @categoria = Texto.limpar(categoria)
      @observacoes = Texto.limpar(observacoes)
      @status = self.class.status_de(status)
      @avaliacao = inteiro(avaliacao)
      freeze
    end

    def erros
      lista = []
      lista << "Título é obrigatório." if titulo.nil?
      lista << "Autor é obrigatório." if autor.nome.nil?
      lista << "Ano deve ser um número entre 1 e #{Date.today.year}." unless self.class.ano_valido?(ano)
      lista << "ISBN deve ter 10 ou 13 dígitos." unless self.class.isbn_valido?(isbn)
      lista << "Status deve ser: #{STATUS.values.join(', ')}." unless STATUS.key?(status)
      lista.concat(erros_da_avaliacao)
    end

    def lido?
      status == :lido
    end

    def avaliado?
      lido? && !avaliacao.nil?
    end

    def status_texto
      STATUS.fetch(status, status.to_s)
    end

    def decada
      ano && (ano / 10) * 10
    end

    # Campos editáveis, prontos para criar um novo Livro.
    def atributos
      { titulo: titulo, autor: autor.nome, ano: ano, isbn: isbn, categoria: categoria,
        observacoes: observacoes, status: status, avaliacao: avaliacao }
    end

    def to_h
      super.merge(atributos).merge(status: status.to_s)
    end

    private

    def erros_da_avaliacao
      return [] if avaliacao.nil?
      return ["Avaliação deve ser de 1 a 5 estrelas."] unless avaliacao.is_a?(Integer) && AVALIACOES.cover?(avaliacao)
      return ["Só livros lidos podem ser avaliados."] unless lido?

      []
    end

    def inteiro(valor)
      return nil if valor.nil? || valor.to_s.strip.empty?
      return valor if valor.is_a?(Integer)

      Integer(valor.to_s.strip, 10, exception: false) || valor
    end
  end
end
