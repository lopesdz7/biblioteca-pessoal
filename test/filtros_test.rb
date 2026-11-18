# frozen_string_literal: true

require_relative "test_helper"

class FiltrosTest < Minitest::Test
  include Biblioteca
  include Fabrica

  def setup
    @acervo = acervo_de_exemplo
  end

  def titulos(*filtros)
    @acervo.filtrar(*filtros).map(&:titulo)
  end

  def test_filtros_sao_lambdas
    assert Filtros.titulo("x").lambda?
    assert_raises(ArgumentError) { Filtros.titulo("x").call }
  end

  def test_titulo_e_autor_por_parte_do_texto_sem_acento
    assert_equal ["Eu, Robô"], titulos(Filtros.titulo("robo"))
    assert_equal ["Eu, Robô", "Fundação"], titulos(Filtros.autor("ASIMOV"))
  end

  def test_ano_categoria_e_status_exatos
    assert_equal ["1984"], titulos(Filtros.ano(1949))
    assert_equal ["Duna", "Eu, Robô", "Fundação"], titulos(Filtros.categoria("Ficção Científica"))
    assert_empty titulos(Filtros.categoria("Ficção"))
    assert_equal ["Clean Code"], titulos(Filtros.status("Lendo"))
  end

  def test_avaliacao_exata_ou_por_faixa
    assert_equal ["1984", "Fundação"], titulos(Filtros.avaliacao(5))
    assert_equal ["1984", "Eu, Robô", "Fundação"], titulos(Filtros.avaliacao(4..5))
  end

  def test_combina_varios_criterios
    ficcao_nao_lida = Filtros.todos(Filtros.categoria("ficção científica"), Filtros.status(:nao_lido))
    cinco_estrelas_do_asimov = Filtros.todos(Filtros.avaliacao(5), Filtros.autor("Asimov"))

    assert_equal ["Duna"], titulos(ficcao_nao_lida)
    assert_equal ["Fundação"], titulos(cinco_estrelas_do_asimov)
    assert_equal ["Clean Code", "Duna"], titulos(Filtros.algum(Filtros.status(:lendo), Filtros.ano(1965)))
    assert_equal ["Sem Ano"], titulos(Filtros.negar(:ano.to_proc))
  end

  def test_filtros_prontos
    prontos = Filtros.prontos

    assert_equal ["Duna"], titulos(prontos["Ficção científica não lida"])
    assert_equal ["1984"], titulos(prontos["Clássicos (publicados antes de 1950)"])
    assert_equal ["Sem Ano"], titulos(prontos["Sem categoria"])
    refute prontos["Lidos e ainda sem avaliação"].lambda?
  end
end
