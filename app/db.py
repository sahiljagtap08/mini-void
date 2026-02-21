from sqlalchemy import create_engine, Column, Integer, Text
from sqlalchemy.orm import declarative_base, sessionmaker

engine = create_engine("sqlite:////app/data/brain.db")
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()


class Chunk(Base):
    __tablename__ = "chunks"
    id = Column(Integer, primary_key=True)
    content = Column(Text)


Base.metadata.create_all(bind=engine)
