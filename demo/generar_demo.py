"""Genera los datos FICTICIOS de la demo de CV UP (feria) y los deja en demo/02a…02d_datos_*.sql.

Ninguna persona es real: nombres, documentos, correos y teléfonos se inventan con una semilla fija (siempre salen
los mismos). Los avisos también son inventados. Lo que sí es real es el cálculo: los postulantes se cargan en una base
SQLite temporal y se rankean con el mismo código del scraper (scraping/ranking.py, modelo multilingual e5) y el mismo
análisis de trayectoria, así que los puntajes, explicaciones y alertas son los que daría el sistema de verdad.

Uso (desde la carpeta CV_UP, con un Python que tenga sentence-transformers y el modelo e5 en caché):
    python demo/generar_demo.py
Sin el modelo e5, el ranking cae a tfidf (funciona, pero los puntajes se parecen menos a los reales).
"""
import json
import logging
import random
import sys
import tempfile
import unicodedata
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ))

from scraping import ranking  # noqa: E402
from scraping.cargar_diccionario import filas_base  # noqa: E402
from scraping.db import BD  # noqa: E402

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("demo")

SALIDA = RAIZ / "demo" / "02a_datos_avisos_postulantes.sql"   # y 02b, 02c, 02d en la misma carpeta
HOY = date(2026, 11, 25)
rnd = random.Random(2026)

# ---------------------------------------------------------------------------------------------------- avisos
AVISOS = [
    {
        "aviso_id": "9000000101", "titulo": "Analista de Datos", "publicado_el": "2026-11-10", "n": 64,
        "area": "Tecnología, Sistemas y Telecomunicaciones", "subarea": "Business Intelligence", "nivel": "Semi Senior",
        "sueldo": (3500, 6000),
        "requisitos": [
            "Bachiller o titulado en Ingeniería de Sistemas, Ingeniería Industrial, Estadística, Economía o carreras afines.",
            "Experiencia mínima de 2 años en análisis de datos, reportes de gestión o inteligencia de negocios.",
            "Dominio de SQL y Excel avanzado (tablas dinámicas, Power Query).",
            "Conocimiento de Power BI o Tableau para la construcción de dashboards.",
            "Deseable conocimiento de Python para análisis y automatización de procesos.",
        ],
        "funciones": [
            "Construir y mantener dashboards de indicadores para las áreas de negocio.",
            "Extraer, limpiar y consolidar información de distintas fuentes de datos.",
            "Elaborar reportes de gestión y presentar hallazgos a las jefaturas.",
        ],
        "preguntas": {"¿Qué nivel de SQL manejas?": ["Avanzado, uso joins y funciones de ventana a diario.", "Intermedio, consultas con joins y agrupaciones.", "Básico.", "No he usado SQL."]},
        "afines": {
            "puestos": ["Analista de Datos", "Analista de Inteligencia de Negocios", "Analista BI", "Analista de Reportes", "Data Analyst", "Analista de Planeamiento"],
            "areas": [("Tecnología, Sistemas y Telecomunicaciones", "Business Intelligence"), ("Administración, Contabilidad y Finanzas", "Planeamiento")],
            "desc": ["Elaboración de dashboards en Power BI y automatización de reportes con SQL y Python.",
                     "Consultas SQL sobre el data warehouse, modelado de datos y reportes de ventas en Power BI.",
                     "Análisis de indicadores comerciales en Excel avanzado y Tableau; limpieza de bases de datos.",
                     "Automatización de procesos con Python (pandas) y mantenimiento de tableros de gestión."],
            "estudios": [("Ingeniería de Sistemas", "Ingeniería en Sistemas"), ("Ingeniería Industrial", "Ingeniería Industrial"),
                         ("Estadística", "Estadística"), ("Economía", "Economía"), ("Ciencia de Datos", "Ingeniería en Sistemas")],
            "cursos": ["Especialización en Power BI", "Python para Análisis de Datos", "SQL para Análisis de Datos"],
        },
    },
    {
        "aviso_id": "9000000102", "titulo": "Ejecutivo(a) de Atención al Cliente", "publicado_el": "2026-11-12", "n": 72,
        "area": "Atención al Cliente, Call Center y Telemarketing", "subarea": "Atención al Cliente", "nivel": "Junior",
        "sueldo": (1300, 2000),
        "requisitos": [
            "Estudios técnicos o universitarios en Administración, Marketing, Comunicaciones o carreras afines.",
            "Experiencia mínima de 1 año en atención al cliente presencial, telefónica o por canales digitales.",
            "Manejo de Excel a nivel intermedio y de sistemas CRM.",
            "Habilidades de comunicación, empatía y orientación a la solución de reclamos.",
        ],
        "funciones": [
            "Atender consultas, solicitudes y reclamos de los clientes por los distintos canales.",
            "Registrar cada caso en el CRM y hacer seguimiento hasta su cierre.",
            "Proponer mejoras en la experiencia del cliente.",
        ],
        "preguntas": {"¿Cuentas con disponibilidad para trabajar de lunes a sábado en horario rotativo?": ["Sí, tengo disponibilidad completa.", "Sí.", "No, solo de lunes a viernes."]},
        "afines": {
            "puestos": ["Ejecutivo de Atención al Cliente", "Asesor de Servicio al Cliente", "Agente de Call Center", "Representante de Servicio", "Asesor de Reclamos"],
            "areas": [("Atención al Cliente, Call Center y Telemarketing", "Atención al Cliente"), ("Atención al Cliente, Call Center y Telemarketing", "Call Center")],
            "desc": ["Atención de consultas y reclamos por teléfono, chat y redes sociales; registro de casos en el CRM.",
                     "Atención presencial en plataforma, resolución de reclamos y fidelización de clientes.",
                     "Gestión de solicitudes de clientes en Salesforce y reportes de atención en Excel intermedio."],
            "estudios": [("Administración de Empresas", "Adm. de Empresas"), ("Marketing", "Marketing"), ("Ciencias de la Comunicación", "Comunicación"),
                         ("Administración de Negocios Internacionales", "Adm. de Empresas")],
            "cursos": ["Curso de Servicio al Cliente", "Excel Intermedio", "Gestión de Reclamos"],
        },
    },
    {
        "aviso_id": "9000000103", "titulo": "Ejecutivo(a) Comercial B2B", "publicado_el": "2026-11-05", "n": 58,
        "area": "Comercial, Ventas y Negocios", "subarea": "Ventas", "nivel": "Semi Senior",
        "sueldo": (2500, 4500),
        "requisitos": [
            "Bachiller en Administración, Marketing, Ingeniería Industrial o carreras afines.",
            "Experiencia mínima de 2 años en ventas consultivas B2B o gestión de cartera corporativa.",
            "Conocimiento de herramientas CRM (Salesforce, HubSpot) y Excel intermedio.",
            "Orientación a resultados y cumplimiento de metas comerciales.",
        ],
        "funciones": [
            "Prospectar y captar nuevos clientes corporativos.",
            "Elaborar propuestas comerciales y negociar condiciones.",
            "Gestionar la cartera de clientes y el cumplimiento de la cuota mensual.",
        ],
        "preguntas": {"¿Cuál es tu expectativa salarial mensual?": ["Entre S/ 3000 y S/ 3500 más comisiones.", "S/ 2800 más variable.", "S/ 4500.", "A tratar."]},
        "afines": {
            "puestos": ["Ejecutivo Comercial", "Key Account Manager", "Ejecutivo de Ventas Corporativas", "Asesor Comercial B2B", "Ejecutivo de Negocios"],
            "areas": [("Comercial, Ventas y Negocios", "Ventas"), ("Comercial, Ventas y Negocios", "Comercial")],
            "desc": ["Venta consultiva a empresas, gestión de cartera de 60 clientes corporativos y cumplimiento de cuota.",
                     "Prospección de clientes B2B, elaboración de propuestas y seguimiento en Salesforce; reportes de ventas en Excel intermedio.",
                     "Negociación con clientes corporativos y apertura de nuevas cuentas; pipeline en HubSpot y Excel intermedio."],
            "estudios": [("Administración de Empresas", "Adm. de Empresas"), ("Marketing", "Marketing"), ("Ingeniería Industrial", "Ingeniería Industrial")],
            "cursos": ["Diplomado en Gestión Comercial", "Técnicas de Negociación", "Salesforce para Ventas"],
        },
    },
    {
        "aviso_id": "9000000104", "titulo": "Coordinador(a) Académico(a)", "publicado_el": "2026-11-14", "n": 48,
        "area": "Educación, Docencia e Investigación", "subarea": "Gestión Académica", "nivel": "Senior",
        "sueldo": (3000, 5000),
        "requisitos": [
            "Titulado en Educación, Administración, Psicología o carreras afines; deseable maestría en gestión educativa.",
            "Experiencia mínima de 3 años en coordinación o gestión académica en universidades o institutos.",
            "Experiencia en programación de cursos, docentes y aulas.",
            "Manejo de Excel intermedio y plataformas educativas (Moodle, Blackboard o Canvas).",
        ],
        "funciones": [
            "Programar los cursos, docentes y aulas de cada periodo académico.",
            "Atender a estudiantes y docentes y hacer seguimiento a la calidad académica.",
            "Elaborar reportes de matrícula, asistencia y rendimiento.",
        ],
        "preguntas": {"¿Tienes experiencia usando Moodle, Blackboard o Canvas?": ["Sí, administré aulas en Canvas.", "Sí, como usuario de Moodle.", "No."]},
        "afines": {
            "puestos": ["Coordinador Académico", "Asistente Académico", "Analista de Gestión Académica", "Coordinadora de Programas", "Secretaria Académica"],
            "areas": [("Educación, Docencia e Investigación", "Gestión Académica"), ("Educación, Docencia e Investigación", "Docencia")],
            "desc": ["Programación de cursos y docentes por ciclo, atención a estudiantes y reportes de matrícula en Excel intermedio.",
                     "Coordinación de programas de pregrado, seguimiento de sílabos y gestión de aulas en Canvas.",
                     "Soporte a la dirección académica, control de asistencia docente y elaboración de indicadores."],
            "estudios": [("Educación", "Educación"), ("Administración", "Adm. de Empresas"), ("Psicología", "Psicología"),
                         ("Maestría en Gestión Educativa", "Educación")],
            "cursos": ["Diplomado en Gestión Educativa", "Administración de Moodle", "Excel Intermedio"],
            "empresas": ["Universidad de Lima", "Pontificia Universidad Católica del Perú", "UPC", "USIL", "Instituto Cibertec",
                         "Universidad del Pacífico", "Colegio San Agustín", "Instituto IDAT"],
        },
    },
    {
        "aviso_id": "9000000105", "titulo": "Asistente de Marketing Digital", "publicado_el": "2026-11-17", "n": 52,
        "area": "Marketing y Publicidad", "subarea": "Marketing Digital", "nivel": "Junior",
        "sueldo": (1500, 2500),
        "requisitos": [
            "Egresado o bachiller en Marketing, Comunicaciones, Publicidad o carreras afines.",
            "Experiencia mínima de 1 año gestionando redes sociales y campañas digitales.",
            "Manejo de Meta Ads, Google Ads y Google Analytics.",
            "Conocimiento de herramientas de diseño como Canva o Adobe Photoshop.",
        ],
        "funciones": [
            "Planificar y publicar contenido en las redes sociales de la empresa.",
            "Configurar y optimizar campañas pagadas en Meta y Google.",
            "Medir resultados y preparar reportes mensuales.",
        ],
        "preguntas": {"¿Has gestionado campañas pagadas con presupuesto propio?": ["Sí, con presupuestos de más de S/ 5 000 al mes.", "Sí, campañas pequeñas.", "No, solo contenido orgánico."]},
        "afines": {
            "puestos": ["Asistente de Marketing Digital", "Community Manager", "Analista de Marketing Digital", "Especialista en Redes Sociales", "Practicante de Marketing"],
            "areas": [("Marketing y Publicidad", "Marketing Digital"), ("Comunicación, Relaciones Institucionales y Públicas", "Comunicación")],
            "desc": ["Gestión de redes sociales, calendario de contenidos y campañas en Meta Ads y Google Ads.",
                     "Diseño de piezas en Canva y Photoshop; reportes de métricas con Google Analytics.",
                     "Optimización de campañas de conversión y análisis de resultados mensuales."],
            "estudios": [("Marketing", "Marketing"), ("Ciencias de la Comunicación", "Comunicación"), ("Publicidad", "Publicidad")],
            "cursos": ["Certificación Google Ads", "Meta Blueprint", "Marketing Digital"],
        },
    },
]

OTROS = {   # experiencia y estudios que no tienen que ver con el aviso (para el ranking bajo)
    "puestos": [("Auxiliar de Almacén", "Abastecimiento y Logística", "Almacén / Depósito / Expedición", "Recepción y despacho de mercadería, control de inventarios."),
                ("Cajero", "Comercial, Ventas y Negocios", "Ventas", "Atención en caja, cuadre de caja diario y arqueos."),
                ("Asistente Contable", "Administración, Contabilidad y Finanzas", "Contabilidad", "Registro de compras y ventas, conciliaciones bancarias."),
                ("Mozo", "Gastronomía y Turismo", "Restaurantes", "Atención de mesas y toma de pedidos."),
                ("Operario de Producción", "Producción y Manufactura", "Producción", "Operación de máquinas en línea de envasado."),
                ("Asistente Administrativo", "Administración, Contabilidad y Finanzas", "Administración", "Archivo de documentos, trámites y apoyo a gerencia."),
                ("Promotor de Ventas", "Comercial, Ventas y Negocios", "Ventas", "Promoción de productos en punto de venta."),
                ("Técnico de Soporte", "Tecnología, Sistemas y Telecomunicaciones", "Soporte Técnico", "Soporte a usuarios e instalación de equipos.")],
    "estudios": [("Contabilidad", "Contabilidad"), ("Derecho", "Derecho"), ("Enfermería", "Salud"), ("Gastronomía", "Gastronomía"),
                 ("Ingeniería Civil", "Ingeniería Civil"), ("Mecánica Automotriz", "Mecánica")],
}

EMPRESAS_TOP = ["BCP", "Interbank", "BBVA", "Rimac Seguros", "Pacífico Seguros", "Saga Falabella", "Tottus", "Sodimac", "Ripley",
                "Telefónica del Perú", "Claro Perú", "Entel Perú", "Alicorp", "Backus", "Deloitte", "PwC", "KPMG", "Yape", "Rappi", "Scotiabank"]
EMPRESAS_PYME = ["Inversiones Andinas SAC", "Comercial Los Olivos EIRL", "Servicios Integrales del Sur SAC", "Distribuidora Pacífico SAC",
                 "Grupo Altamar SAC", "Corporación Lince SAC", "Soluciones Norte SAC", "Textiles Miraflores SAC", "Logística Callao SAC",
                 "Consultora Horizonte SAC", "Importaciones Rímac SAC", "Agencia Creativa Barranco SAC"]
INDUSTRIAS = ["Banca / Financiera", "Seguros", "Retail", "Telecomunicaciones", "Consumo masivo", "Consultoría", "Comercio", "Servicios",
              "Educación", "Tecnología", "Alimenticia", "Logística"]
UNIVERSIDADES = ["Universidad de Lima", "Universidad del Pacífico", "Pontificia Universidad Católica del Perú", "Universidad Nacional Mayor de San Marcos",
                 "Universidad Peruana de Ciencias Aplicadas", "Universidad San Ignacio de Loyola", "Universidad Tecnológica del Perú",
                 "Universidad Nacional de Ingeniería", "Universidad Ricardo Palma", "Universidad César Vallejo"]
INSTITUTOS = ["Instituto Cibertec", "SENATI", "Instituto IDAT", "Toulouse Lautrec", "ISIL", "Certus"]
DISTRITOS = ["Santiago de Surco", "San Miguel", "Los Olivos", "San Juan de Lurigancho", "Miraflores", "Jesús María", "La Molina", "Ate",
             "Surquillo", "Comas", "Chorrillos", "Pueblo Libre", "San Borja", "Villa El Salvador", "Callao", "Lince", "Magdalena del Mar"]
NOMBRES_F = ["María", "Lucía", "Andrea", "Valeria", "Camila", "Daniela", "Fiorella", "Milagros", "Rosa", "Claudia", "Sofía",
             "Ximena", "Paola", "Gabriela", "Carla", "Diana", "Kiara", "Alejandra", "Mariana", "Fernanda", "Jimena", "Lorena"]
NOMBRES_M = ["José", "Luis", "Carlos", "Jorge", "Miguel", "Diego", "Renzo", "Alonso", "Sebastián", "Juan", "Kevin", "Bruno",
             "Gonzalo", "Ricardo", "Piero", "Andrés", "Manuel", "Rodrigo", "César", "Javier", "Franco", "Adrián"]
APELLIDOS = ["Quispe", "Flores", "Rodríguez", "Sánchez", "García", "Rojas", "Huamán", "Chávez", "Torres", "Ramírez", "Mendoza",
             "Vargas", "Castillo", "Espinoza", "Gutiérrez", "Romero", "Díaz", "Salazar", "Paredes", "Medina", "Vásquez", "Ríos",
             "Cáceres", "Palacios", "Benites", "Aguilar", "Silva", "Herrera", "Zevallos", "Valdivia", "Cornejo", "Montoya"]
IDIOMAS = ["Inglés - Básico", "Inglés - Intermedio", "Inglés - Avanzado", "Inglés - Intermedio, Portugués - Básico", ""]


def ascii_(t):
    return unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode().lower().replace(" ", "")


def mes(d: date) -> str:
    return d.replace(day=1).isoformat()


def restar_meses(d: date, m: int) -> date:
    y, mm = divmod(d.year * 12 + d.month - 1 - m, 12)
    return date(y, mm + 1, 1)


def experiencias(aviso, perfil):
    """Lista de experiencias (más reciente primero) según qué tan afín es el perfil al aviso."""
    af = aviso["afines"]
    top = af.get("empresas", EMPRESAS_TOP)

    def afin(meses, practica=False, empresa=None):
        area, sub = rnd.choice(af["areas"])
        puesto = ("Practicante de " + aviso["titulo"].split("(")[0].split(" de ")[-1].strip()) if practica else rnd.choice(af["puestos"])
        return dict(puesto=puesto, area=area, sub=sub, desc=rnd.choice(af["desc"]), meses=meses,
                    empresa=empresa or (rnd.choice(top) if rnd.random() < 0.45 else rnd.choice(EMPRESAS_PYME)))

    def otra(meses):
        p, area, sub, desc = rnd.choice(OTROS["puestos"])
        return dict(puesto=p, area=area, sub=sub, desc=desc, meses=meses, empresa=rnd.choice(EMPRESAS_PYME + EMPRESAS_TOP[:6]))

    if perfil == "alto":
        exps = [afin(rnd.randint(14, 40)) for _ in range(rnd.randint(2, 3))]
        if rnd.random() < 0.4:
            exps.append(afin(rnd.randint(4, 10), practica=True))
    elif perfil == "medio":
        exps = [afin(rnd.randint(6, 20))] + [otra(rnd.randint(6, 24)) for _ in range(rnd.randint(0, 2))]
        rnd.shuffle(exps)
        if rnd.random() < 0.35:
            exps.insert(0, afin(rnd.randint(3, 8), practica=True))
    elif perfil == "rotacion":
        # Cuatro o cinco contratos cortos seguidos, con un mes entre uno y otro: el análisis de trayectoria lo marca como
        # patrón de rotación (3 cambios de empleador en 6 meses). El CSV de Bumeran no trae la modalidad de contrato y por eso
        # en los datos reales casi siempre sale «información insuficiente»; aquí se declara «Planilla» para que la alerta se vea.
        exps = [afin(rnd.randint(1, 2)) if i % 2 == 0 else otra(1) for i in range(rnd.randint(4, 5))]
        fin = restar_meses(HOY, rnd.randint(1, 3))
        salida = []
        for e in exps:
            inicio = restar_meses(fin, e["meses"])
            salida.append({**e, "contrato": "Planilla", "inicio": mes(inicio), "fin": mes(fin)})
            fin = restar_meses(inicio, 1)
        return salida
    elif perfil == "estudiante":
        exps = [afin(rnd.randint(3, 6), practica=True)] if rnd.random() < 0.5 else []
    else:
        exps = [otra(rnd.randint(6, 30)) for _ in range(rnd.randint(1, 3))]
    # Fechas hacia atrás desde hoy, con algún hueco entre trabajos; el más reciente puede seguir vigente
    fin = HOY if rnd.random() < 0.55 else restar_meses(HOY, rnd.randint(1, 5))
    salida = []
    for i, e in enumerate(exps):
        inicio = restar_meses(fin, e["meses"])
        actual = i == 0 and fin == HOY
        salida.append({**e, "inicio": mes(inicio), "fin": "" if actual else mes(fin)})
        fin = restar_meses(inicio, rnd.choice([0, 0, 1, 2, 4]))
    return salida


def estudios(aviso, perfil):
    af = aviso["afines"]
    if perfil in ("alto", "rotacion"):
        titulo, area = rnd.choice(af["estudios"])
        nivel = "Master" if titulo.startswith("Maestría") else "Universitario"
        estado = "Graduado" if nivel == "Master" or rnd.random() < 0.85 else "En Curso"
        inst = rnd.choice(UNIVERSIDADES)
    elif perfil in ("medio", "estudiante"):
        titulo, area = rnd.choice(af["estudios"])
        titulo = titulo.replace("Maestría en ", "")
        nivel = rnd.choice(["Universitario", "Universitario", "Terciario/Técnico"])
        estado = "En Curso" if perfil == "estudiante" or rnd.random() < 0.4 else "Graduado"
        inst = rnd.choice(UNIVERSIDADES if nivel == "Universitario" else INSTITUTOS)
    else:
        titulo, area = rnd.choice(OTROS["estudios"])
        nivel = rnd.choice(["Universitario", "Terciario/Técnico", "Secundario"])
        estado = rnd.choice(["Graduado", "En Curso", "Abandonado"])
        inst = rnd.choice(UNIVERSIDADES if nivel == "Universitario" else INSTITUTOS)
        if nivel == "Secundario":
            titulo, area, inst, estado = "Secundaria Completa", "Otra", "I.E. " + rnd.choice(APELLIDOS), "Graduado"
    anio_fin = HOY.year - rnd.randint(0, 6)
    lista = [dict(nivel=nivel, titulo=titulo if nivel == "Secundario" else ("Bachiller en " if nivel == "Universitario" and estado == "Graduado" and rnd.random() < 0.3 else "") + titulo,
                  area=area, estado=estado, inst=inst,
                  inicio=f"{anio_fin - (2 if nivel == 'Master' else 5 if nivel == 'Universitario' else 3)}-03-01",
                  fin="" if estado == "En Curso" else f"{anio_fin}-12-01")]
    if perfil in ("alto", "medio") and rnd.random() < 0.6:
        lista.append(dict(nivel="Curso", titulo=rnd.choice(af["cursos"]), area="Otra", estado="Graduado",
                          inst=rnd.choice(["Coursera", "Platzi", "Cibertec", "New Horizons", "Google"]),
                          inicio=f"{HOY.year - 1}-04-01", fin=f"{HOY.year - 1}-07-01"))
    lista.append(dict(nivel="Secundario", titulo="Secundaria Completa", area="Otra", estado="Graduado",
                      inst="I.E. " + rnd.choice(["San José", "Santa Rosa", "Juana Alarco", "Bartolomé Herrera", "Melitón Carvajal"]),
                      inicio="2010-03-01", fin="2015-12-01"))
    return lista


def persona(aviso, k, usados):
    perfil = rnd.choices(["alto", "medio", "bajo", "rotacion", "estudiante"], [0.22, 0.38, 0.24, 0.09, 0.07])[0]
    mujer = rnd.random() < 0.55
    nombre = rnd.choice(NOMBRES_F if mujer else NOMBRES_M)
    ap1, ap2 = rnd.sample(APELLIDOS, 2)
    while (nombre, ap1, ap2) in usados:
        ap2 = rnd.choice(APELLIDOS)
    usados.add((nombre, ap1, ap2))
    nacimiento = date(HOY.year - rnd.randint(21 if perfil == "estudiante" else 23, 42), rnd.randint(1, 12), rnd.randint(1, 28))
    dni = f"7{rnd.randint(1000000, 9999999)}"
    fila = {
        "Nombre": nombre, "Apellido": f"{ap1} {ap2}",
        "E-Mail": f"{ascii_(nombre)}.{ascii_(ap1)}{rnd.randint(1, 99)}@example.com",
        "Tipo Documento": "DNI", "Nro. Documento": dni,
        "Teléfono celular": f"900000{rnd.randint(100, 999)}", "Otro teléfono": "",
        "Fecha de nacimiento": nacimiento.isoformat(), "Edad": str((HOY - nacimiento).days // 365),
        "Género": "femenino" if mujer else "masculino", "Estado Civil": rnd.choice(["Soltero/a", "Soltero/a", "Casado/a"]),
        "Nacionalidad": "Peru", "Dirección": "Dirección de ejemplo",
        "Ciudad": rnd.choice(DISTRITOS), "Lugar de residencia": "Lima",
        "Idiomas": rnd.choice(IDIOMAS[1:3] if perfil == "alto" else IDIOMAS),
        "Fecha Postulación": (date.fromisoformat(aviso["publicado_el"]) + timedelta(days=rnd.randint(0, (HOY - date.fromisoformat(aviso["publicado_el"])).days))).isoformat(),
    }
    lo, hi = aviso["sueldo"]
    fila["Preferencia Salarial"] = str(round(rnd.uniform(lo * 0.85, hi * (1.15 if perfil == "alto" else 0.95)) / 100) * 100)
    for i, e in enumerate(experiencias(aviso, perfil), 1):
        fila.update({f"Exp[{i}] Puesto": e["puesto"], f"Exp[{i}] Empresa": e["empresa"], f"Exp[{i}] Area": e["area"],
                     f"Exp[{i}] SubArea": e["sub"], f"Exp[{i}] Industria": rnd.choice(INDUSTRIAS), f"Exp[{i}] Pais": "Peru",
                     f"Exp[{i}] Descripción": e["desc"], f"Exp[{i}] Fecha Inicio": e["inicio"], f"Exp[{i}] Fecha Fin": e["fin"],
                     f"Exp[{i}] Gente a cargo": ""})
        if e.get("contrato"):
            fila[f"Exp[{i}] Tipo de contrato"] = e["contrato"]
    for i, s in enumerate(estudios(aviso, perfil), 1):
        fila.update({f"Est[{i}] Nivel": s["nivel"], f"Est[{i}] Titulo": s["titulo"], f"Est[{i}] Area": s["area"],
                     f"Est[{i}] Estado": s["estado"], f"Est[{i}] Institucion": s["inst"], f"Est[{i}] Pais": "Peru",
                     f"Est[{i}] Fecha Inicio": s["inicio"], f"Est[{i}] Fecha Fin": s["fin"]})
    for pregunta, respuestas in aviso["preguntas"].items():
        fila[pregunta] = respuestas[0 if perfil == "alto" and rnd.random() < 0.7 else rnd.randrange(len(respuestas))]
    return fila


def detalle(a):
    req = "\n".join(a["requisitos"])
    fun = "\n".join(a["funciones"])
    texto = (f"Empresa líder en su sector se encuentra en la búsqueda del mejor talento para la posición de {a['titulo'].upper()}.\n\n"
             f"Requisitos:\n\n{req}\nDisponibilidad para trabajar de manera presencial en Lima.\n\nFunciones:\n\n{fun}\n\n"
             "Ofrecemos:\n\nIngreso a planilla con todos los beneficios de ley.\nLínea de carrera y capacitación constante.")
    html = "".join(f"<p>{l}</p>" for l in texto.split("\n") if l)
    return {"url": f"https://demo.cvup.pe/empleos/{a['aviso_id']}", "titulo": a["titulo"], "empresa": "Confidencial",
            "migas": ["Bolsa de empleo", a["area"], a["subarea"], "Lima", "Lima", "Presencial"],
            "ubicacion": "Lima, Lima, Peru",
            "caracteristicas": ["Presencial", a["subarea"], "Full-time, Indeterminado", a["nivel"], "1 vacante disponible"],
            "descripcion_html": html, "descripcion_texto": texto}


# ---------------------------------------------------------------------------------------------------- SQL
def lit(v):
    if v is None:
        return "null"
    if isinstance(v, (int, float)):
        return repr(v)
    return "'" + str(v).replace("'", "''") + "'"


def inserts(bd, tabla, columnas, where="", orden=""):
    filas = bd.consultar(f"SELECT {', '.join(columnas)} FROM {tabla} {where} {orden}")
    if not filas:
        return f"-- {tabla}: sin filas\n"
    out = [f"insert into public.{tabla} ({', '.join(columnas)}) values"]
    out.append(",\n".join("  (" + ", ".join(lit(f[c]) for c in columnas) + ")" for f in filas) + ";")
    return "\n".join(out) + "\n"


def alta_rotacion_sqlite(bd, aviso_id):
    """Igual que ranking.alta_rotacion (que solo lee Supabase): penaliza a quien tiene el patrón de rotación detectado."""
    return {r["clave"] for r in bd.consultar(
        "SELECT clave FROM gth_trayectoria_analisis WHERE aviso_id=? AND estado='patron_detectado'", (aviso_id,))}


def main():
    ranking.alta_rotacion = alta_rotacion_sqlite
    tmp = Path(tempfile.mkdtemp(prefix="cvup_demo_")) / "demo.db"
    bd = BD(ruta=tmp)
    ahora = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    bd.upsert_lista([{"aviso_id": a["aviso_id"], "titulo": a["titulo"], "estado": "Publicado", "publicado_el": a["publicado_el"],
                      "creado_por": "Equipo CV UP", "visitas": a["n"] * rnd.randint(4, 7), "recibidos": a["n"],
                      "no_leidos": rnd.randint(0, 9)} for a in AVISOS])
    usados = set()
    for a in AVISOS:
        bd.guardar_detalle(a["aviso_id"], detalle(a))
        filas = [persona(a, k, usados) for k in range(a["n"])]
        nuevos, total = bd.importar_csv(a["aviso_id"], filas)
        bd.marcar(a["aviso_id"], ultimo_csv_at=ahora, recibidos_al_scrapear=total)
        log.info("%s: %d postulantes ficticios", a["titulo"], total)
        ranking.paso_ranking(bd, {"aviso_id": a["aviso_id"]}, forzar=True)
        bd.marcar(a["aviso_id"], ranking_at=ahora)

    backends = {r["backend"] for r in bd.consultar("SELECT DISTINCT backend FROM ranking_embeddings")}
    log.info("Ranking calculado con: %s", ", ".join(sorted(backends)))

    def cabecera(titulo, nota):
        return "\n".join([
            "-- =============================================================================================",
            f"-- CV UP · {titulo}. TODO ES FICTICIO: personas, documentos, correos, teléfonos y avisos.",
            f"-- Generado con demo/generar_demo.py el {date.today().isoformat()} (ranking: {', '.join(sorted(backends))}).",
            f"-- {nota}",
            "-- =============================================================================================",
            "begin;", ""])

    archivos = {
        "02a_datos_avisos_postulantes.sql": cabecera(
            "Datos de la demo 1/4: avisos y postulantes",
            "Correr después de 01_estructura.sql. Se puede volver a correr: borra los datos de demo anteriores.") + "\n".join([
            "-- Deja la demo como nueva: borra también lo que los visitantes hayan cambiado (etapas, marcas, comentarios, pesos…)",
            "delete from public.gth_trayectoria_revisiones; delete from public.gth_feedback_ranking; delete from public.gth_aviso_reglas;",
            "delete from public.gth_aviso_requisitos; delete from public.gth_aviso_criterios; delete from public.gth_aviso_calibracion;",
            "delete from public.gth_sueldos_ofertados; delete from public.ranking_recalculos; delete from public.gth_avance;",
            "delete from public.gth_acciones; delete from public.comentarios_internos; delete from public.en_revision;",
            "delete from public.gth_correos_enviados; delete from public.gth_correos_postulante; delete from public.multitest_envios;",
            "delete from public.solicitudes; delete from public.avisos_confidenciales;",
            "delete from public.ranking_embeddings; delete from public.gth_trayectoria_analisis; delete from public.postulaciones;",
            "delete from public.cvs; delete from public.avisos; delete from public.scrape_runs;", "",
            inserts(bd, "avisos", ["aviso_id", "titulo", "estado", "publicado_el", "creado_por", "visitas", "recibidos", "no_leidos",
                                   "recibidos_al_scrapear", "url_publica", "detalle_json", "detalle_texto", "detalle_at", "ultimo_csv_at",
                                   "ultima_revision_at", "primera_vez_at", "en_ultima_lista", "criterios", "criterios_version", "ranking_at"]),
            inserts(bd, "postulaciones", ["aviso_id", "clave", "id_postulante", "documento", "email", "nombre", "apellido",
                                          "fecha_postulacion", "datos_json", "en_ultimo_csv", "primera_vez_at", "actualizado_at"],
                    orden="ORDER BY aviso_id, id_postulante"),
            inserts(bd, "scrape_runs", ["tipo", "aviso_id", "inicio", "fin", "estado", "nuevos", "total", "mensaje"], orden="ORDER BY id"),
            "commit;", ""]),
        "02b_datos_ranking.sql": cabecera("Datos de la demo 2/4: ranking e5 de cada postulante", "Correr después de 02a.") + "\n".join([
            inserts(bd, "ranking_embeddings", ["aviso_id", "clave", "id_postulante", "criterios_version", "backend", "ranking", "score",
                                               "score_bruto", "req_sims", "req_sims_bruto", "req_fragmentos", "explicacion",
                                               "explicacion_bruta", "calculado_at", "ajustes"], orden="ORDER BY aviso_id, ranking"),
            "commit;", ""]),
        "02d_datos_empresas.sql": cabecera("Datos de la demo 4/4: diccionario de empresas Tier 1 / Tier 1.5",
                                           "El mismo diccionario de base que usa el ranking. Se puede correr en cualquier momento.") + "\n".join([
            "alter table public.gth_empresas_diccionario disable trigger diccionario_recalculo;",
            "insert into public.gth_empresas_diccionario (alias, tier, sector, exacto, origen) values",
            ",\n".join(f"  ({lit(al)}, {lit(t)}, {lit(s)}, {'true' if e else 'false'}, 'base')" for al, (t, s, e) in filas_base().items())
            + "\non conflict (alias) do nothing;",
            "alter table public.gth_empresas_diccionario enable trigger diccionario_recalculo;",
            "commit;", ""]),
    }
    # Trayectoria: un archivo por aviso (el detalle de cada análisis es largo y el SQL Editor de Supabase rechaza ~1 MB)
    for i, a in enumerate(AVISOS, 1):
        archivos[f"02c{i}_datos_trayectoria.sql"] = cabecera(
            f"Datos de la demo 3/4 (parte {i} de {len(AVISOS)}): trayectoria laboral · {a['titulo']}", "Correr después de 02a.") + "\n".join([
            inserts(bd, "gth_trayectoria_analisis", ["id", "aviso_id", "clave", "id_postulante", "huella", "version", "estado",
                                                     "fecha_referencia", "vigente_hasta", "calculado_at", "detalle"],
                    where=f"WHERE aviso_id = '{a['aviso_id']}'", orden="ORDER BY clave"),
            "commit;", ""])
    for viejo in SALIDA.parent.glob("02*_datos_*.sql"):
        viejo.unlink()
    for nombre, texto in sorted(archivos.items()):
        (SALIDA.parent / nombre).write_text(texto, encoding="utf-8")
        log.info("%s: %d KB", nombre, len(texto.encode("utf-8")) // 1024)
    n = bd.uno("SELECT COUNT(*) AS n FROM postulaciones")["n"]
    rot = bd.uno("SELECT COUNT(*) AS n FROM gth_trayectoria_analisis WHERE estado='patron_detectado'")["n"]
    log.info("Listo: %d avisos, %d postulantes, %d con alerta de rotación", len(AVISOS), n, rot)
    bd.cerrar()


if __name__ == "__main__":
    main()
