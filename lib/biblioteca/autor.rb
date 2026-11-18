# frozen_string_literal: true

module Biblioteca
  # Autor de um livro. O Livro é composto por um Autor (composição).
  # Dois autores são iguais mesmo com maiúsculas ou acentos diferentes,
  # então "machado de assis" e "Machado de Assis" contam juntos nas estatísticas.
  class Autor
    include Comparable

    attr_reader :nome

    def initialize(nome)
      @nome = Texto.limpar(nome)
    end

    def chave
      Texto.normalizar(nome)
    end

    def <=>(outro)
      return nil unless outro.is_a?(Autor)

      chave <=> outro.chave
    end

    def eql?(outro)
      self == outro
    end

    def hash
      chave.hash
    end

    def to_s
      nome.to_s
    end
  end
end
