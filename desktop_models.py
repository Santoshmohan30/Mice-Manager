"""
Desktop-specific models that match the actual database schema
"""

from sqlalchemy import Column, Integer, String, Text, Date, Boolean, Float, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()

class Mouse(Base):
    __tablename__ = 'mouse'
    
    id = Column(Integer, primary_key=True)
    strain = Column(String(100))
    gender = Column(String(10))
    genotype = Column(String(50))
    dob = Column(String(20))
    cage = Column(String(20))
    notes = Column(Text)
    training = Column(Boolean, default=False)
    project = Column(String(100))
    
    def __repr__(self):
        return f"<Mouse {self.id} | {self.strain} | {self.gender}>"

class Breeding(Base):
    __tablename__ = 'breeding'
    
    id = Column(Integer, primary_key=True)
    male_id = Column(Integer, ForeignKey('mouse.id'))
    female_id = Column(Integer, ForeignKey('mouse.id'))
    pair_date = Column(Date)
    litter_count = Column(Integer)
    litter_date = Column(Date)
    wean_date = Column(Date)
    notes = Column(Text)
    
    male = relationship("Mouse", foreign_keys=[male_id])
    female = relationship("Mouse", foreign_keys=[female_id])
    
    def __repr__(self):
        return f"<Breeding {self.id} | Male: {self.male_id} | Female: {self.female_id}>"

class Procedure(Base):
    __tablename__ = 'procedure'
    
    id = Column(Integer, primary_key=True)
    mouse_id = Column(Integer, ForeignKey('mouse.id'))
    type = Column(String(100))
    date = Column(Date)
    notes = Column(Text)
    
    mouse = relationship("Mouse")
    
    def __repr__(self):
        return f"<Procedure {self.id} | Mouse: {self.mouse_id} | Type: {self.type}>"

class CalendarEvent(Base):
    __tablename__ = 'calendar_event'
    
    id = Column(Integer, primary_key=True)
    title = Column(String(200))
    date = Column(Date)
    category = Column(String(50))
    notes = Column(Text)
    
    def __repr__(self):
        return f"<CalendarEvent {self.id} | {self.title} | {self.date}>"

class Pup(Base):
    __tablename__ = 'pup'
    
    id = Column(Integer, primary_key=True)
    breeding_id = Column(Integer, ForeignKey('breeding.id'))
    sex = Column(String(10))
    genotype = Column(String(50))
    birth_date = Column(Date)
    notes = Column(Text)
    
    breeding = relationship("Breeding")
    
    def __repr__(self):
        return f"<Pup {self.id} | Sex: {self.sex} | Genotype: {self.genotype}>"

class User(Base):
    __tablename__ = 'user'
    
    id = Column(Integer, primary_key=True)
    username = Column(String(80), unique=True)
    email = Column(String(120))
    password_hash = Column(String(200))
    
    def __repr__(self):
        return f"<User {self.id} | {self.username}>"

class Weight(Base):
    __tablename__ = 'weight'
    
    id = Column(Integer, primary_key=True)
    mouse_id = Column(Integer, ForeignKey('mouse.id'))
    weight = Column(Float)
    date = Column(Date)
    notes = Column(Text)
    
    mouse = relationship("Mouse")
    
    def __repr__(self):
        return f"<Weight {self.id} | Mouse: {self.mouse_id} | Weight: {self.weight}>"

class CageTransfer(Base):
    __tablename__ = 'cage_transfer'
    
    id = Column(Integer, primary_key=True)
    mouse_id = Column(Integer, ForeignKey('mouse.id'))
    new_cage = Column(String(20))
    transfer_date = Column(Date)
    notes = Column(Text)
    
    mouse = relationship("Mouse")
    
    def __repr__(self):
        return f"<CageTransfer {self.id} | Mouse: {self.mouse_id} | New Cage: {self.new_cage}>" 