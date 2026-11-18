# frozen_string_literal: true

require_relative "test_helper"

class LivroTest < Minitest::Test
  include Biblioteca

  def test_status_padrao_e_nao_lido_e_campos_sao_limpos
    livro = Livro.new(titulo: "  Duna ", autor: " Frank   Herbert ", categoria: "")

    assert_equal "Duna", livro.titulo
    assert_equal "Frank Herbert", livro.autor.nome
    assert_nil livro.categoria
    assert_equal :nao_lido, livro.status
    assert livro.valido?
  end

  def test_titulo_e_autor_sao_obrigatorios
    erros = Livro.new(titulo: " ", autor: nil).erros

    assert_includes erros, "Título é obrigatório."
    assert_includes erros, "Autor é obrigatório."
  end

  def test_valida_ano_isbn_e_status
    erros = Livro.new(titulo: "X", autor: "Y", ano: "dois mil", isbn: "123", status: "Perdido").erros

    assert_equal 3, erros.size
    assert(erros.any? { |e| e.start_with?("Ano deve") })
    assert_includes erros, "ISBN deve ter 10 ou 13 dígitos."
    assert(erros.any? { |e| e.start_with?("Status deve") })
    assert Livro.new(titulo: "X", autor: "Y", isbn: "0-201-61622-X").valido?
    refute Livro.new(titulo: "X", autor: "Y", ano: Date.today.year + 1).valido?
  end

  def test_avaliacao_so_para_livros_lidos_e_de_1_a_5
    assert_includes Livro.new(titulo: "X", autor: "Y", status: :lendo, avaliacao: 4).erros,
                    "Só livros lidos podem ser avaliados."
    assert_includes Livro.new(titulo: "X", autor: "Y", status: :lido, avaliacao: 6).erros,
                    "Avaliação deve ser de 1 a 5 estrelas."
    assert Livro.new(titulo: "X", autor: "Y", status: "Lido", avaliacao: "5").avaliado?
  end

  def test_aceita_status_em_texto
    assert_equal :lendo, Livro.new(titulo: "X", autor: "Y", status: "Lendo").status
    assert_equal :nao_lido, Livro.new(titulo: "X", autor: "Y", status: "nao_lido").status
    assert_equal :nao_lido, Livro.new(titulo: "X", autor: "Y", status: "não lido").status
  end

  def test_herda_de_registro_e_e_imutavel
    livro = Livro.new(titulo: "X", autor: "Y")

    assert_kind_of Registro, livro
    assert livro.frozen?
    assert_raises(NotImplementedError) { Registro.new.erros }
  end

  def test_converte_para_hash_e_volta
    livro = Livro.new(id: 7, titulo: "1984", autor: "George Orwell", ano: 1949, status: :lido, avaliacao: 5)
    hash = JSON.parse(JSON.generate(livro.to_h))
    copia = Livro.from_h(hash)

    assert_equal "lido", hash["status"]
    assert_equal livro.atributos, copia.atributos
    assert_equal 7, copia.id
    assert_equal 1940, copia.decada
  end

  def test_autores_iguais_sem_diferenciar_maiusculas_e_acentos
    assert_equal Autor.new("Guimarães Rosa"), Autor.new("guimaraes rosa")
    assert_equal 1, [Autor.new("Ana"), Autor.new("ANA")].uniq.size
  end
end
