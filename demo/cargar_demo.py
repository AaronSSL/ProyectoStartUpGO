"""Carga la demo de CV UP en Supabase de una sola vez (alternativa a pegar los SQL en el SQL Editor).

Uso (desde la carpeta CV_UP; necesita psycopg: pip install "psycopg[binary]"):
    python demo/cargar_demo.py "<cadena de conexión>"                 -> estructura + datos (proyecto nuevo y vacío)
    python demo/cargar_demo.py "<cadena de conexión>" --solo-datos    -> solo datos: deja la demo como nueva
    python demo/cargar_demo.py "<cadena de conexión>" --cuenta demo@cvup.pe   -> además da acceso a esa cuenta

La cadena de conexión está en Supabase -> botón «Connect» -> «Session pooler» (postgresql://postgres.xxxx:CLAVE@...).
No la guardes en archivos del repo: pásala solo al correr el comando.
"""
import argparse
from pathlib import Path

CARPETA = Path(__file__).resolve().parent
DATOS = sorted(p.name for p in CARPETA.glob("02*_datos_*.sql"))   # 02a, 02b, 02c1…02c5, 02d


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("conexion", help="cadena de conexión de Supabase (Session pooler)")
    p.add_argument("--solo-datos", action="store_true", help="no crea la estructura; solo recarga los datos de la demo")
    p.add_argument("--cuenta", help="correo de la cuenta de la demo, ya creada en Authentication -> Users")
    args = p.parse_args()

    import psycopg
    archivos = ([] if args.solo_datos else ["01_estructura.sql"]) + DATOS
    with psycopg.connect(args.conexion, autocommit=True, prepare_threshold=None) as cx:
        if not args.solo_datos and cx.execute("select to_regclass('public.avisos')").fetchone()[0]:
            raise SystemExit("La base ya tiene la estructura. Para recargar solo los datos usa --solo-datos.")
        for nombre in archivos:
            cx.execute((CARPETA / nombre).read_text(encoding="utf-8"))
            print("✓", nombre)
        if args.cuenta:
            sql = (CARPETA / "03_usuario_demo.sql").read_text(encoding="utf-8").replace("demo@cvup.pe", args.cuenta)
            cx.execute(sql)
            ok = cx.execute("select nivel from public.gth_perfiles where email = %s", (args.cuenta,)).fetchone()
            print("✓ cuenta", args.cuenta, "->", ok[0] if ok else "NO ENCONTRADA: créala primero en Authentication -> Users")
        n = cx.execute("select count(*) from public.postulaciones").fetchone()[0]
        print(f"Listo: {n} postulantes ficticios cargados.")


if __name__ == "__main__":
    main()
